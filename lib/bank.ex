defmodule Bank do
  require IEx

  def read_csv(file) do
    File.stream!(file)
    |> CSV.decode(headers: true)
    |> Stream.filter(fn(x) -> !same_account_transfer?(x) end )
  end

  def calculate_totals(records) do
    income = records
    |> Stream.filter(fn(x) -> is_income?(x) end)
    |> Enum.reduce(0, fn(x, acc) -> acc + convert_amount(x) end)

    expense = records
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> Enum.reduce(0, fn(x, acc) -> acc + convert_amount(x) end)
    savings = income - expense

    %{income: income, expense: expense, savings: savings}
  end

  def add_year(records) do
    records
    |> Stream.map(fn(x) -> Map.put(x, :year, extract_year(x)) end)
  end

  defp convert_amount(amount) do
    amount["Bedrag (EUR)"]
    |> String.to_float
  end

  def add_month(records) do
    records
    |> Stream.map(fn(x) -> Map.put(x, :month, extract_month(x)) end)
  end

  defp same_account_transfer?(record) do
    Regex.match?(~r/(van|naar)/, String.downcase record["Naam / Omschrijving"]) &&
      record["MutatieSoort"] == "Internetbankieren"
  end

  def is_income?(record), do: record["Af Bij"] == "Bij"
  def is_expense?(record), do: record["Af Bij"] == "Af"

  defp extract_year(record) do
    String.slice(record["Datum"], 0..3)
  end

  defp extract_month(record) do
    String.slice(record["Datum"], 4..5)
  end
end
