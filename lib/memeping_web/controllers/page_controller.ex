defmodule MemePingWeb.PageController do
  use MemePingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
