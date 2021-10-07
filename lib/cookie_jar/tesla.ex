if Code.ensure_loaded?(Tesla) do
  defmodule CookieJar.Tesla do
    alias Tesla.Env

    @behaviour Tesla.Middleware

    @impl Tesla.Middleware
    def call(env, next, cookie_jar) do
      env
      |> add_cookie_headers(cookie_jar)
      |> Tesla.run(next)
      |> pour_set_cookie_headers(cookie_jar)
    end

    defp add_cookie_headers(%Env{headers: orig_headers, url: url} = env, jar) do
      jar_cookies = CookieJar.label(jar, url)

      new_headers =
        orig_headers
        |> Enum.into(%{})
        |> Map.update("Cookie", jar_cookies, fn user_cookies ->
          "#{user_cookies}; #{jar_cookies}"
        end)
        |> Enum.into([])

      %Env{env | headers: new_headers}
    end

    defp pour_set_cookie_headers({:error, _reason} = error, _jar), do: error

    defp pour_set_cookie_headers({:ok, %Env{headers: resp_headers, url: url} = env}, jar) do
      cookies =
        Enum.flat_map(resp_headers, fn {key, value} ->
          case String.downcase(key) do
            "set-cookie" -> [value]
            _ -> []
          end
        end)

      CookieJar.pour(jar, cookies, url)

      {:ok, env}
    end
  end
end
