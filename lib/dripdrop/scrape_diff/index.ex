defmodule Dripdrop.CrawlSite do
  use Task

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

  def poll() do
    receive do
    after
      5_000 ->
        diff_dom()
        poll()
    end
  end

  def diff_dom() do
    :inets.start()
    :ssl.start()

    html =
      case :httpc.request('https://acrnm.com/') do
        {:ok, {_status, _headers, body}} ->
          parse_product_links(body)
          |> crawl_links

        {:error, reason} ->
          IO.puts(reason)
      end
  end

  defp parse_product_links(html) do
    html
    |> Floki.parse()
    |> Floki.find(".tile-list a")
    |> Floki.attribute("href")
    |> Enum.filter(fn url -> String.contains?(url, "products") end)
  end

  defp crawl_links(urls) do
    urls
    |> Enum.map(fn url ->
      url
      |> crawl_link("https://acrnm.com")
      |> parse_product_info
    end)
  end

  defp crawl_link(path, base) do
    (base <> path)
    |> to_charlist
    |> :httpc.request()
  end

  defp parse_product_info(html) do
    IO.inspect(html)
  end
end
