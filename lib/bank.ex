defmodule Bank do
  def read_csv do
    File.stream!("lib/transactions.csv")
    |> CSV.decode(headers: true)
    |> Stream.filter(fn(x) -> !same_account_transfer?(x) end)
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

  def supermarkets do
    read_csv
    |> Stream.filter(fn(x) -> is_supermarket?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
  end

  def annual_expense_by_month do
    read_csv
    |> group_by_year
    |> calculate_monthly_expense_by_year
  end

  def annual_income_by_month do
    read_csv
    |> group_by_year
    |> calculate_monthly_income_by_year
  end

  defp group_by_year(records) do
    records
    |> Stream.map(fn(x) ->
         Map.put(x, :year, (String.slice(x["Datum"], 0..3)))
       end)
    |> Enum.group_by(&(&1[:year]))
  end

  defp calculate_monthly_expense_by_year(records) do
    records
    |> Enum.reduce(%{},
      fn({k, v}, acc) -> Map.update(acc, k, expense_by_month(v),
                                    expense_by_month(v)) end)
  end

  defp calculate_monthly_income_by_year(records) do
    records
    |> Enum.reduce(%{},
      fn({k, v}, acc) -> Map.update(acc, k, income_by_month(v),
                                    income_by_month(v)) end)
  end

  defp expense_by_month(records) do
    records
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> Enum.reduce(%{}, fn(record, acc) -> update_month(record, acc) end)
  end

  defp income_by_month(records) do
    records
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

  defp is_supermarket?(record) do
    supermarkets = ~r/(albert(\s*)heijn(.*))|((.*)lidl(.*))|(plus(.*))|((.*)hoogvliet(.*))|(jumbo(.*))/
    Regex.match?(supermarkets, String.downcase record["Naam / Omschrijving"])
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

  defp same_account_transfer?(record) do
    Regex.match?(~r/(van|naar) toprekening/, String.downcase record["Naam / Omschrijving"])
  end
end
