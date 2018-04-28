defmodule Pushest.Socket.Data.Presence do
  @moduledoc ~S"""
  Structure representing presence information, connected user IDs and data of them.
  """

  @type t :: %__MODULE__{
          count: integer,
          hash: map,
          ids: list(integer),
          me: map
        }

  defstruct count: 0, hash: %{}, ids: [], me: %{}

  @doc ~S"""
  Merges current Presence struct with new presence data frame. Always keeps :me
  part from current state.

  ## Examples

      iex> Pushest.Socket.Data.Presence.merge(%Pushest.Socket.Data.Presence{count: 1, ids: [1]}, nil)
      %Pushest.Socket.Data.Presence{count: 1, ids: [1]}

      iex> Pushest.Socket.Data.Presence.merge(
      ...> %Pushest.Socket.Data.Presence{me: %{user_id: 1}},
      ...> %{"count" => 1, "ids" => [1]}
      ...> )
      %Pushest.Socket.Data.Presence{count: 1, ids: [1], hash: nil, me: %{user_id: 1}}
  """
  @spec merge(%__MODULE__{}, %__MODULE__{} | nil) :: %__MODULE__{}
  def merge(current, nil), do: current

  def merge(current, next) do
    decoded = decode(next)

    %__MODULE__{
      count: decoded.count,
      hash: decoded.hash,
      ids: decoded.ids,
      me: current.me
    }
  end

  @doc ~S"""
  Adds new user data to a Presence struct and returns new one containg the merge.
  Used when member_added event is being fired to merge new user to local presence.

  ## Examples

        iex> Pushest.Socket.Data.Presence.add_member(
        ...> %Pushest.Socket.Data.Presence{me: %{user_id: "1"}, count: 1, ids: ["1"], hash: %{"1" => nil}},
        ...> %{"user_id" => "2", "user_info" => %{"name" => "Tomas Koutsky"}}
        ...> )
        %Pushest.Socket.Data.Presence{
          me: %{user_id: "1"},
          count: 2, ids: ["2", "1"],
          hash: %{"1" => nil, "2" => %{"name" => "Tomas Koutsky"}}
        }
  """
  @spec add_member(%__MODULE__{}, map) :: %__MODULE__{}
  def add_member(%__MODULE__{count: count, hash: hash, ids: ids, me: me}, %{
        "user_id" => user_id,
        "user_info" => user_info
      }) do
    %__MODULE__{
      count: count + 1,
      ids: [user_id | ids],
      hash: Map.merge(hash, %{user_id => user_info}),
      me: me
    }
  end

  @doc ~S"""
  Removes user data from a Presence struct and returns new one without given user data.
  Used when member_removed event is being fired to remove that user from local presence.

  ## Examples

        iex> Pushest.Socket.Data.Presence.remove_member(
        ...> %Pushest.Socket.Data.Presence{me: %{user_id: "1"}, count: 2, ids: ["1", "2"], hash: %{"1" => nil, "2" => nil}},
        ...> %{"user_id" => "2"}
        ...> )
        %Pushest.Socket.Data.Presence{
          me: %{user_id: "1"},
          count: 1, ids: ["1"],
          hash: %{"1" => nil}
        }
  """
  @spec remove_member(%__MODULE__{}, map) :: %__MODULE__{}
  def remove_member(%__MODULE__{count: count, hash: hash, ids: ids, me: me}, %{
        "user_id" => user_id
      }) do
    %__MODULE__{
      count: count - 1,
      ids: List.delete(ids, user_id),
      hash: Map.delete(hash, user_id),
      me: me
    }
  end

  @spec decode(map) :: %__MODULE__{}
  defp decode(presence) do
    %__MODULE__{
      count: presence["count"],
      hash: presence["hash"],
      ids: presence["ids"]
    }
  end
end
