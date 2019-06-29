defmodule Dripdrop.CrawlSite do
  use Task
  alias Dripdrop.Repo

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

  def poll() do
    receive do
    after
      15_000 ->
        diff_dom()
        poll()
    end
  end

  defp diff_dom() do
    :inets.start()
    :ssl.start()

    case :httpc.request(
           'https://supertalk.superfuture.com/topic/147967-the-acronym-community-sales-thread/'
         ) do
      {:ok, {_status, _headers, body}} -> body
      {:error, reason} -> IO.puts(reason)
    end
  end
end
