defmodule Bank do
  require IEx
  def main(args) do
    args |> parse_args |> process
  end

  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [file: :string, type: :string])
    options
  end

  def process([]), do: IO.puts "No arguments given"
  def process(options) do
    case String.downcase(options[:type]) do
      "income" ->
        annual_income_by_month(options[:file])
      "expense" ->
        annual_expense_by_month(options[:file])
      "supermarket" ->
        supermarkets(options[:file])
      "drugstore" ->
        drugstores(options[:file])
      "transport" ->
        transport(options[:file])
      "household" ->
        household(options[:file])
      "savings" ->
        savings(options[:file])
      _ ->
        IO.puts "Unknown type #{options[:type]}"
    end
  end

  def read_csv(file) do
    File.stream!(file)
    |> CSV.decode(headers: true)
    |> Stream.filter(fn(x) -> !same_account_transfer?(x) end)
  end

  def supermarkets(file) do
    read_csv(file)
    |> Stream.filter(fn(x) -> is_supermarket?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
    |> IO.puts
  end

  def drugstores(file) do
    read_csv(file)
    |> Stream.filter(fn(x) -> is_drugstore?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
    |> IO.puts
  end

  def transport(file) do
    read_csv(file)
    |> Stream.filter(fn(x) -> is_transportation?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
    |> IO.puts
  end

  def household(file) do
    read_csv(file)
    |> Stream.filter(fn(x) -> is_household?(x) end)
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    |> add_amounts
    |> IO.puts
  end

  def annual_expense_by_month(file) do
    read_csv(file)
    |> group_by_year
    |> calculate_monthly_expense_by_year
    |> calculate_totals
    |> IO.inspect
  end

  def savings(file) do
    read_csv(file)
    |> group_by_year
    |> calculate_income_and_expense
    |> IO.inspect
  end

  defp calculate_income_and_expense(records) do
    Enum.reduce(records, %{}, fn({k, v}, acc) ->
      Map.put(acc, k, income_expense_savings(v)) end)
  end

  def income_expense_savings(record) do
    income  = income_by_month(record)
    income  = Map.put(income, :total, Enum.sum(Map.values(income)))
    expense = expense_by_month(record)
    expense = Map.put(expense, :total, Enum.sum(Map.values(expense)))
    savings = Enum.reduce(income, %{}, fn({k, v}, acc) ->
      Map.put(acc, k, income[k] - expense[k]) end)
    %{income: income, expense: expense, savings: savings}
  end

  def annual_income_by_month(file) do
    read_csv(file)
    |> group_by_year
    |> calculate_monthly_income_by_year
    |> calculate_totals
    |> IO.inspect
  end

  defp calculate_totals(records) do
    Enum.reduce(records, %{}, fn({k, v}, acc) ->
      Map.put(acc, k, Map.put(v, :total, Enum.sum(Map.values(v)))) end)
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

  defp is_drugstore?(record) do
    drugstores = ~r/(kruidvat(.*))|(etos(.*))|(trekpleister(.*))/
    Regex.match?(drugstores, String.downcase record["Naam / Omschrijving"])
  end

  defp is_transportation?(record) do
    Regex.match?(~r/(ns-(.*))|(ns (.*))/, String.downcase record["Naam / Omschrijving"])
  end

  defp is_household?(record) do
    household = ~r/(blokker(.*))|(ikea(.*))|(xenos(.*))|(hema(.*))|(kwantum(.*))/
    Regex.match?(household, String.downcase record["Naam / Omschrijving"])
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
