defmodule Dripdrop.CrawlSite do
  use Task
  use DripdropWeb, :controller

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
    IO.puts("Fetching html from: #{baseUrl}")

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
    |> Enum.filter(fn url -> String.contains?(url, "products") end)
  end

  def crawl_product(path, base) do
    url = base <> path
    IO.puts("Crawling page: #{url}")

    case Mojito.get(url) do
      {:ok, %{body: body}} ->
        {body, path}
        |> parse_product_info
        |> insert_or_get_product
        |> insert_or_update_skus

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

  defp insert_or_update_skus({{:ok, product}, skus}) do
    skus
    |> Enum.map(fn [color, size] ->
      product
      |> Ecto.build_assoc(:skus)
      |> SKU.changeset(%{color: color, size: size})
    end)
    |> Enum.each(fn changeset ->
      sku_msg = "#{product.model_code} SKU: #{changeset.changes.color}, #{changeset.changes.size}"

      case Repo.insert(changeset) do
        {:ok, _sku} -> IO.puts("Saved #{sku_msg}")
        {:error, _changeset} -> IO.puts("Failed to save #{sku_msg}")
      end
    end)
  end
end
