defmodule Bank do
  require IEx

  def read_csv(file) do
    File.stream!(file)
    |> CSV.decode(headers: true)
    |> Stream.filter(fn(x) -> !same_account_transfer?(x) end )
  end

  def compute_results(file) do
    file
    |> read_csv
    |> add_month
    |> add_year
    |> group_by_year_and_month
    |> calculate_annual_totals
    |> format
  end

  def format(data) do
    IO.puts "Banking report"
    :io.format("~40p~n", [data])
  end

  def calculate_annual_totals(records) do
    records
    |> Enum.reduce(%{}, fn({k, v}, acc) ->
         Map.put(acc, k, Enum.reduce(v, %{}, fn({k, v}, acc) ->
           Map.put(acc, k, Bank.calculate_monthly_totals(v))
         end)
         )
       end)
  end
  def calculate_monthly_totals(records) do
    income = records
    |> Stream.filter(fn(x) -> is_income?(x) end)
    |> Enum.reduce(0, fn(x, acc) -> acc + convert_amount(x) end)

    expense = records
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> Enum.reduce(0, fn(x, acc) -> acc + convert_amount(x) end)
    savings = income - expense

    %{income: income, expense: expense, savings: savings}
  end

  def group_by_year_and_month(records) do
    records
    |> group_by_year
    |> Enum.reduce(%{}, fn({k, v}, acc) ->
         Map.put(acc, k, group_by_month(v)) end)
  end

  def group_by_year(records) do
    Enum.group_by(records, fn(x) -> x[:year] end)
  end

  def group_by_month(records) do
    Enum.group_by(records, fn(x) -> x[:month] end)
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
    |> String.to_integer
  end

  defp extract_month(record) do
    String.slice(record["Datum"], 4..5)
    |> String.to_integer
  end
end
