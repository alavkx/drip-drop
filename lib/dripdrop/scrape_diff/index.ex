defmodule Dripdrop.CrawlSite do
  use Task
  use DripdropWeb, :controller
  import Ecto.Query

  alias Dripdrop.Repo
  alias Dripdrop.Product
  alias Dripdrop.SKU

  def start_link(_arg), do: Task.start_link(&poll/0)

  def poll() do
    main()

    receive do
    after
      120_000 ->
        main()
        poll()
    end
  end

  def main() do
    baseUrl = "https://acrnm.com"
    IO.puts("#{DateTime.utc_now()}- Fetching html from: #{baseUrl}")

    {:ok, %{body: body}} = Mojito.get(baseUrl)

    [product_release_msg, sku_restock_msg] =
      body
      |> parse_product_links
      |> Task.async_stream(Dripdrop.CrawlSite, :crawl_product, [baseUrl],
        max_concurrency: 10,
        ordered: false
      )
      |> Enum.map(fn {:ok, val} -> val end)
      |> transpose
      |> build_product_releases_msg
      |> build_sku_restocks_msg

    unless is_nil(product_release_msg) do
      IO.puts(product_release_msg)
    end

    unless is_nil(sku_restock_msg) do
      IO.puts(sku_restock_msg)
    end
  end

  defp parse_product_links(html) do
    html
    |> Floki.parse()
    |> Floki.find(".tile-list a")
    |> Floki.attribute("href")
    |> Enum.filter(&String.contains?(&1, "products"))
  end

  def crawl_product(path, base) do
    IO.puts("Crawling page: #{path}")

    case Mojito.get(base <> path) do
      {:ok, %{body: body}} ->
        {body, path}
        |> parse_product_info
        |> insert_or_get_product
        |> insert_or_get_skus
        |> update_missing_skus_not_in_stock
        |> build_stock_update_msg

      {:error, _reason} ->
        {nil, nil}
    end
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

  defp insert_or_get_product({skus, product_params}) do
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
        product
        |> Ecto.build_assoc(:skus)
        |> SKU.changeset(%{color: color, size: size})
        |> Repo.insert!()

      sku ->
        {:ok, sku}
    end
  end

  defp insert_or_get_skus({product_type, {:ok, product}, skus}) do
    skus = Enum.map(skus, &insert_or_get_sku(&1, product))

    {{product_type, product}, skus}
  end

  defp update_missing_skus_not_in_stock({{product_type, product}, skus}) do
    sku_ids = Enum.map(skus, fn {_, x} -> x.id end)

    {_numEntries, restocked_skus} =
      from(s in SKU,
        where: s.product_id == ^product.id and not (s.id in ^sku_ids) and s.in_stock == true,
        select: s
      )
      |> Repo.update_all(set: [in_stock: false])

    {{product_type, product}, restocked_skus}
  end

  defp build_stock_update_msg({{status, product}, restocked_skus}) do
    product_title = "#{product.model_code} #{product.generation}"

    product_msg =
      case status do
        :new_product -> product_title
        :existing_product -> nil
      end

    sku_msgs =
      case length(restocked_skus) == 0 do
        true ->
          nil

        false ->
          Enum.map(restocked_skus, fn %{color: color, size: size} ->
            "#{product_title}: #{size} / #{color}"
          end)
      end

    {product_msg, sku_msgs}
  end

  defp transpose(rows) do
    rows
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp build_product_releases_msg([product_msgs, sku_msgs]) do
    product_msgs = Enum.reject(product_msgs, &is_nil/1)

    release_msg =
      case length(product_msgs) == 0 do
        true ->
          nil

        false ->
          "New products detected\n" <> Enum.join(product_msgs, " / ")
      end

    [release_msg, sku_msgs]
  end

  defp build_sku_restocks_msg([release_msg, sku_msgs]) do
    sku_msgs = Enum.reject(sku_msgs, &is_nil/1)

    restock_msg =
      case length(sku_msgs) == 0 do
        true -> nil
        false -> "Restock detected\n" <> Enum.join(sku_msgs, " / ")
      end

    [release_msg, restock_msg]
  end
end
