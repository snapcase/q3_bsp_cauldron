defmodule Q3BspCauldron.Router do
  use Plug.Router
  require Logger

  plug(:match)
  plug(:dispatch)

  get "/dl/:mapname" do
    mapname = conn.params["mapname"]
    Logger.info("Download request for map: #{mapname}")

    case Q3BspCauldron.BSPMonitor.get_pk3_for_bsp(mapname) do
      {:ok, pk3_file} ->
        serve_pk3_file(conn, pk3_file)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Map '#{mapname}' not found")
    end
  end

  # catch-all for unmatched routes
  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp serve_pk3_file(conn, pk3_file) do
    baseq3_path = System.get_env("QUAKE3_BASEQ3_PATH") || "/opt/quake3/baseq3"
    file_path = Path.join(baseq3_path, pk3_file)

    case File.stat(file_path) do
      {:ok, %File.Stat{size: size}} ->
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{pk3_file}"))
        |> put_resp_header("content-length", Integer.to_string(size))
        |> send_file(200, file_path)

      {:error, reason} ->
        Logger.error("Failed to read file #{pk3_file}: #{reason}")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Internal server error")
    end
  end
end
