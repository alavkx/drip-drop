defmodule Dripdrop.CrawlSite do
  use Task

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

  def poll() do
    receive do
    after
      5_000 ->
        main()
        poll()
    end
  end

  def main() do
    body =
      case Mojito.request(:get, "https://acrnm.com/") do
        {:ok, %Mojito.Response{body: body}} -> body
        {:error, reason} -> IO.puts(reason)
      end

    body
    |> parse_product_links
    |> Enum.map(fn url ->
      url
      |> crawl_link("https://acrnm.com")
      |> parse_product_info
    end)
  end

  defp parse_product_links(html) do
    html
    |> Floki.parse()
    |> Floki.find(".tile-list a")
    |> Floki.attribute("href")
    |> Enum.filter(fn url -> String.contains?(url, "products") end)
  end

  defp crawl_link(path, base) do
    case Mojito.request(:get, base <> path) do
      {:ok, %Mojito.Response{body: body}} -> {body, path}
      {:error, reason} -> IO.puts(reason)
    end
  end

  defp parse_product_info({body, path}) do
    [name, technology_code, season] =
      path
      |> String.split(["products/", "-", "_"])
      |> Enum.drop(1)

    [description, type, generation, style, price] =
      body
      |> Floki.find(".product-details")
      |> Floki.text()
      |> String.split("Description")
      |> Enum.at(0)
      |> String.split(["Type", "Style", "Price", "Gen", "\n"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn x -> String.length(x) > 0 end)
  end
end
