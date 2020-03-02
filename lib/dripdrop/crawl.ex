defmodule Dripdrop.Crawl do
  use GenServer
  import Ecto.Query

  alias Dripdrop.Repo
  alias Dripdrop.Product
  alias Dripdrop.SKU

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    run()
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    run()
    schedule_work()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:post_message, msg}, state) do
    Mojito.post(
      "https://discordapp.com/api" <> Application.get_env(:dripdrop, :webhook),
      [{"content-type", "application/json"}],
      Jason.encode!(%{"content" => msg})
    )

    {:noreply, state}
  end

  defp post_message(nil), do: nil

  defp post_message(msg) do
    GenServer.call(__MODULE__, {:post_message, msg})
  end

  defp schedule_work do
    Process.send_after(self(), :work, 120_000)
  end

  def run() do
    baseUrl = "https://acrnm.com"
    IO.puts("#{DateTime.utc_now()} - Fetching html from #{baseUrl}")
    {:ok, %{body: body}} = Mojito.get(baseUrl)

    [product_release_msg, sku_restock_msg] =
      body
      |> Floki.parse()
      |> Floki.find(".tile-list a")
      |> Floki.attribute("href")
      |> Enum.filter(&String.contains?(&1, "products"))
      |> Task.async_stream(__MODULE__, :crawl_product, [baseUrl],
        max_concurrency: 10,
        ordered: false
      )
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, val} -> val end)
      |> transpose
      |> build_product_releases_msg
      |> build_sku_restocks_msg

    post_message(product_release_msg)
    post_message(sku_restock_msg)

    IO.puts("#{DateTime.utc_now()} - Finished crawling #{baseUrl}")
  end

  def crawl_product(path, base) do
    {:ok, %{body: body}} = Mojito.get(base <> path)

    {body, path}
    |> parse_product_info
    |> get_or_insert_product
    |> get_or_insert_skus
    |> update_missing_skus_not_in_stock
    |> build_stock_update_msg
  end

  defp parse_product_info({body, path}) do
    [model_code, season] =
      path
      |> String.split(["products/", "_"])
      |> Enum.drop(1)

    skus =
      body
      |> Floki.find("#variety_id option")
      |> Enum.map(fn x -> Floki.text(x) |> String.split(" / ") end)

    [description, type, generation, style, price] =
      body
      |> Floki.find(".product-details")
      |> Floki.text()
      |> String.split("Description")
      |> List.first()
      |> String.split(["Type", "Style", "Price", "Gen.", "\n"])
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn x -> String.length(x) > 0 end)

    {skus,
     %{
       model_code: model_code,
       season: season,
       description: description,
       type: type,
       generation: generation,
       style: style,
       price: price
     }}
  end

  defp get_or_insert_product({skus, product_params}) do
    changeset = Product.changeset(%Product{}, product_params)

    case Repo.get_by(Product,
           model_code: product_params.model_code,
           season: product_params.season,
           generation: product_params.generation
         ) do
      nil -> {:new_product, Repo.insert(changeset), skus}
      product -> {:existing_product, {:ok, product}, skus}
    end
  end

  defp insert_or_get_sku([color, size], product) do
    case Repo.get_by(SKU, color: color, size: size, product_id: product.id) do
      nil ->
        {:new_sku,
         product
         |> Ecto.build_assoc(:skus)
         |> SKU.changeset(%{color: color, size: size})
         |> Repo.insert()}

      %{in_stock: false} = sku ->
        updateResponse =
          sku
          |> SKU.changeset(%{in_stock: true})
          |> Repo.update()

        {:restocked_sku, updateResponse}

      sku ->
        {:existing_sku, {:ok, sku}}
    end
  end

  defp get_or_insert_skus({product_type, {:ok, product}, skus}) do
    skus = Enum.map(skus, &insert_or_get_sku(&1, product))
    {{product_type, product}, skus}
  end

  defp update_missing_skus_not_in_stock({{product_type, product}, skus}) do
    sku_ids = Enum.map(skus, fn {_, {_, x}} -> x.id end)

    from(s in SKU,
      where: s.product_id == ^product.id and not (s.id in ^sku_ids) and s.in_stock == true,
      select: s
    )
    |> Repo.update_all(set: [in_stock: false])

    {{product_type, product}, skus}
  end

  defp fmt_sku_display_name(s) do
    "#{s.size} / #{s.color}"
  end

  defp build_stock_update_msg({{product_type, product}, skus}) do
    restocked_skus =
      Enum.filter(skus, fn {sku_type, {_, _}} ->
        sku_type == :restocked_sku || (product_type == :existing_product && sku_type == :new_sku)
      end)

    product_url = "https://acrnm.com/products/#{product.model_code}_#{product.season}"
    product_link = "[#{product.model_code}](#{product_url})"

    product_msg =
      if product_type == :new_product do
        product_link
      end

    restocked_skus_msg =
      if length(restocked_skus) > 0 do
        msg =
          restocked_skus
          |> Enum.map(fn {_, {_, sku}} -> fmt_sku_display_name(sku) end)
          |> Enum.join(", ")

        "#{product_link}: " <> msg
      end

    IO.puts("\t#{product.model_code}")

    Enum.each(skus, fn {sku_type, {_, sku}} ->
      IO.puts("\t\t#{sku_type} -> #{fmt_sku_display_name(sku)} / id#{sku.id}")
    end)

    {product_msg, restocked_skus_msg}
  end

  defp transpose(rows) do
    rows
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp build_product_releases_msg([product_msgs, sku_msgs]) do
    product_msgs = Enum.reject(product_msgs, &is_nil/1)
    msg = "Drop detected\n" <> Enum.join(product_msgs, " / ")

    release_msg =
      if length(product_msgs) > 0 do
        msg
      end

    [release_msg, sku_msgs]
  end

  defp build_sku_restocks_msg([release_msg, sku_msgs]) do
    sku_msgs = Enum.reject(sku_msgs, &is_nil/1)

    restock_msg =
      if length(sku_msgs) > 0 do
        "Restock detected\n" <> Enum.join(sku_msgs, "\n")
      end

    [release_msg, restock_msg]
  end
end
