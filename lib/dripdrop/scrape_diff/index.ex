defmodule Dripdrop.CrawlSite do
  use Task
  alias Dripdrop.Repo
  alias Dripdrop.Product

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

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
    out =
      case Mojito.get("https://acrnm.com/") do
        {:ok, %{body: body}} ->
          body
          |> parse_product_links
          |> Enum.map(fn url -> crawl_link(url, "https://acrnm.com") end)

        {:error, reason} ->
          reason
      end

    IO.inspect(out)
  end

  defp parse_product_links(html) do
    html
    |> Floki.parse()
    |> Floki.find(".tile-list a")
    |> Floki.attribute("href")
    |> Enum.filter(fn url -> String.contains?(url, "products") end)
  end

  defp crawl_link(path, base) do
    out =
      case Mojito.get(base <> path) do
        {:ok, %{body: body}} ->
          {body, path}
          |> parse_product_info
          |> insert_or_update_product

        {:error, reason} ->
          {:error, reason}
      end
  end

  defp parse_product_info({body, path}) do
    [model_code, season] =
      path
      |> String.split(["products/", "_"])
      |> Enum.drop(1)

    _skus =
      body
      |> Floki.find("#variety_id option")
      |> Enum.map(fn x -> x |> Floki.text() |> String.split(" / ") end)

    [description, type, generation, style, price] =
      body
      |> Floki.find(".product-details")
      |> Floki.text()
      |> String.split("Description")
      |> Enum.at(0)
      |> String.split(["Type", "Style", "Price", "Gen.", "\n"])
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn x -> String.length(x) > 0 end)

    %{
      model_code: model_code,
      season: season,
      description: description,
      type: type,
      generation: generation,
      style: style,
      price: price
    }
  end

  defp insert_or_update_product(product_params) do
    changeset = Product.changeset(%Product{}, product_params)

    IO.inspect(product_params)

    case Repo.get_by(Product,
           model_code: product_params.model_code,
           season: product_params.season,
           generation: product_params.generation
         ) do
      nil -> Repo.insert(changeset)
      product -> {:ok, product}
    end
  end
end
