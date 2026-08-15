defmodule BluetteWeb.PageController do
  use BluetteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
