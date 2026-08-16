defmodule BluetteWeb.TermListsLiveTest do
  use BluetteWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Bluette.Accounts.User
  alias Bluette.Notifications.TermLists
  alias Bluette.Repo

  setup %{conn: conn} do
    user = Repo.insert!(User.changeset(%User{}, %{}))
    conn = Plug.Test.init_test_session(conn, %{"user_id" => user.id})
    %{conn: conn, user: user}
  end

  test "creates, edits and deletes a term list", %{conn: conn, user: user} do
    {:ok, live_view, html} = live(conn, ~p"/term-lists")
    assert html =~ "No forbidden term lists yet"

    {:ok, editor, _html} = live(conn, ~p"/term-lists/new")

    editor
    |> form("#term-list-form",
      term_list: %{
        "name" => "Promotional terms",
        "terms" => "hello\n12.*hi\n\n.*dollar.*"
      }
    )
    |> render_submit()

    assert_redirect(editor, ~p"/term-lists")
    assert render(live_view) =~ "No forbidden term lists yet"

    {:ok, _index_live, html} = live(conn, ~p"/term-lists")
    assert html =~ "Promotional terms"
    assert html =~ "3 regexes"

    [term_list] = TermLists.list_term_lists(user)
    assert term_list.terms == "hello\n12.*hi\n.*dollar.*"

    {:ok, edit_live, _html} = live(conn, ~p"/term-lists/#{term_list}/edit")

    edit_live
    |> form("#term-list-form", term_list: %{"name" => "Updated terms", "terms" => "new.*"})
    |> render_submit()

    assert_redirect(edit_live, ~p"/term-lists")

    {:ok, index_live, html} = live(conn, ~p"/term-lists")
    assert html =~ "Updated terms"

    index_live
    |> element("button", "Delete")
    |> render_click()

    assert render(index_live) =~ "No forbidden term lists yet"
  end

  test "rejects duplicate names and invalid regexes", %{conn: conn} do
    {:ok, editor, _html} = live(conn, ~p"/term-lists/new")

    editor
    |> form("#term-list-form", term_list: %{"name" => "Blocked", "terms" => "["})
    |> render_submit()

    assert has_element?(editor, "#term-list-form p.text-error", "invalid regex")

    editor
    |> form("#term-list-form", term_list: %{"name" => "Blocked", "terms" => "hello"})
    |> render_submit()

    {:ok, second_editor, _html} = live(conn, ~p"/term-lists/new")

    second_editor
    |> form("#term-list-form", term_list: %{"name" => "Blocked", "terms" => "world"})
    |> render_submit()

    assert has_element?(second_editor, "#term-list-form p.text-error", "has already been taken")
  end

  test "previews only the first ten expressions", %{conn: conn, user: user} do
    terms = Enum.map_join(1..11, "\n", &"term#{&1}")

    {:ok, _term_list} =
      TermLists.create_term_list(user, %{"name" => "Many terms", "terms" => terms})

    {:ok, _live_view, html} = live(conn, ~p"/term-lists")

    assert html =~ "term1"
    assert html =~ "term10"
    assert html =~ "..."
    refute html =~ "term11"
  end
end
