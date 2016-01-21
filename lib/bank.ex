defmodule Bank do
  def read_csv do
    File.stream!("lib/transactions.csv")
    |> CSV.decode(headers: true)
    |> Stream.filter(fn(x) -> x["Mededelingen"] != "" end)
  end

  def income do
    read_csv
    |> Stream.filter(fn(x) -> is_income?(x) end)
    |> add_amounts
  end

  def expenditure do
    read_csv
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
  end

  def ah do
    read_csv
    |> Stream.filter(fn(x) -> is_AH?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
  end

  def expense_by_month do
    read_csv
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> Enum.reduce(%{}, fn(record, acc) -> update_month(record, acc) end)
  end

  def income_by_month do
    read_csv
    |> Stream.filter(fn(x) -> is_income?(x) end)
    |> Enum.reduce(%{}, fn(record, acc) -> update_month(record, acc) end)
  end

  defp update_month(record, acc) do
    month = String.slice(record["Datum"], 4..5)
    Map.update acc,
        String.to_atom(month),
        get_amount(record),
        &(&1 + get_amount(record))
  end

  defp is_AH?(record) do
    Regex.match?(~r/albert(\s*)heijn(.*)/, String.downcase record["Naam / Omschrijving"])
  end

  defp is_expense?(record), do: record["Af Bij"] == "Af"

  defp is_income?(record), do: record["Af Bij"] == "Bij"

  defp add_amounts(record) do
    record
    |> Stream.map(fn(x) -> x["Bedrag (EUR)"] end)
    |> Stream.map(fn(x) -> String.to_float(x) end)
    |> Enum.reduce(fn(x, acc) -> x + acc end)
  end

  defp get_amount(record) do
    String.to_float(record["Bedrag (EUR)"])
  end
end
