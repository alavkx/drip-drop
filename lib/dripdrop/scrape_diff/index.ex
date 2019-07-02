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

    case Mojito.get(baseUrl) do
      {:ok, %{body: body}} ->
        body
        |> parse_product_links
        |> Task.async_stream(Dripdrop.CrawlSite, :crawl_product, [baseUrl],
          max_concurrency: 10,
          ordered: false
        )
        |> Enum.to_list()

      {:error, reason} ->
        reason
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

      {:error, reason} ->
        {:error, reason}
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
      |> Enum.map(fn x -> x |> Floki.text() |> String.split(" / ") end)

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
      nil -> {Repo.insert(changeset), skus}
      product -> {{:ok, product}, skus}
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

  defp insert_or_get_skus({{:ok, product}, skus}) do
    sku_ids =
      Enum.map(skus, fn sku ->
        sku
        |> insert_or_get_sku(product)
        |> (fn sku -> sku.id end).()
      end)

    {product, sku_ids}
  end

  defp update_missing_skus_not_in_stock({product, sku_ids}) do
    from(s in SKU,
      where: s.product_id == ^product.id and not (s.id in ^sku_ids),
      select: s
    )
    |> Repo.update_all(set: [in_stock: false])
  end
end
