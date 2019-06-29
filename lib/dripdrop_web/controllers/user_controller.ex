defmodule DripdropWeb.UserController do
  use DripdropWeb, :controller

  alias Dripdrop.User
  alias Dripdrop.Repo
  alias DripdropWeb.Router.Helpers

  def new(conn, _params) do
    changeset = User.changeset(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user}) do
    changeset = User.changeset(%User{}, user)

    case insert_or_update_user(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Member added")
        |> redirect(to: Helpers.user_path(conn, :new))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Failed to add member")
        |> render("new.html", changeset: changeset)
    end
  end

  defp insert_or_update_user(changeset) do
    case Repo.get_by(User, email: changeset.changes.email) do
      nil -> Repo.insert(changeset)
      user -> {:ok, user}
    end
  end
end
