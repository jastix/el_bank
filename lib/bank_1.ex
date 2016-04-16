defmodule Bank1 do
  require IEx

  @months ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]

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
    # |> IO.puts
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
    |> present
  end

  def savings(file) do
    # group by year -> group by month -> calculate
    records = read_csv(file)
    records_by_year = records
    |> add_year_and_month
    |> group_by_year

    annual_totals_worker = Task.async(Bank, :calculate_income_and_expense, [ records_by_year ])
    # records_by_month = records_by_year
    # |> group_by_month
    monthly_totals_worker = Task.async(Bank, :calculate_income_and_expense, [ records_by_year ])

    annual_totals = Task.await(annual_totals_worker)
    # IO.puts "*****"
    # IO.inspect annual_totals
    # IO.puts "*****"
    monthly_totals = Task.await(monthly_totals_worker)
    combine([annual_totals, monthly_totals])
    |> present
  end

  def add_year_and_month(records) do
    records
    |> Stream.map(fn(x) ->
      Map.put(x, :year, (String.slice(x["Datum"], 0..3)))
    end)
    |> Stream.map(fn(x) ->
      Map.put(x, :month, (String.slice(x["Datum"], 4..5)))
    end)
  end

  def combine([h, t]) do
    Map.merge(h, t)
  end
  def present(record) do
    IO.puts String.duplicate("-", 40)
    IO.puts String.ljust("|BANKING REPORT", 39) <> "|"
    IO.puts String.duplicate("-", 40)
    Enum.each(record, fn({k, v}) -> print_value({k, v}) end)
  end


  def group_by_month(records) do
    records
    |> Enum.group_by(&(&1[:month]))
  end

  # reduce into year
  def calculate_income_and_expense(records) do
    Enum.reduce(records, %{}, fn({k, v}, acc) ->
      Map.put(acc, k, income_expense_savings(v)) end)
  end

  defp income_expense_savings(record) do
    income_worker = Task.async(Bank, :total_income, [ record ])
    income = Task.await(income_worker)
    records_by_month = group_by_month(record)
    IO.inspect records_by_month
    # income_worker  = Task.async(Bank, :income_by_month,  [ record ])
    # expense_worker = Task.async(Bank, :expense_by_month, [ record ])
    # income_result  = Task.await(income_worker)
    # expense_result = Task.await(expense_worker)
    # IO.inspect expense_result
    # income  = Map.put(income_result, :total, Enum.sum(Map.values(income_result)))
    # expense = Map.put(expense_result, :total, Enum.sum(Map.values(expense_result)))
    # savings = Enum.reduce(income, %{}, fn({k, v}, acc) ->
    #   Map.put(acc, k, income[k] - expense[k]) end)
    # %{income: income, expense: expense, savings: savings}
  end

  def total_income(record) do
    record
    |> Stream.filter(fn(x) -> is_income?(x) end)
    |> add_amounts
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
      fn({k, v}, acc) -> Map.put(acc, k, income_by_month(v)) end)
  end

  def expense_by_month(records) do
    records
    |> Stream.filter(fn(x) -> is_expense?(x) end)
    # |> Enum.reduce(%{}, fn(record, acc) -> update_month(record, acc) end)
  end

  def income_by_month(records) do
    records
    |> Stream.filter(fn(x) -> is_income?(x) end)
    # |> Enum.reduce(%{}, fn(record, acc) -> update_month(record, acc) end)
  end

  def print_value(record, offset \\ 2, length \\ 40)
  def print_value(record, offset, length) when is_map(record) do

    first_column = [String.rjust("|", 12)]

    IO.puts Enum.join(first_column ++ columns(record))
    IO.inspect record
    months = Map.keys record[:expense]
    # Enum.each(months, fn(m) -> IO.puts )
  end

  def print_value({k, v}, offset, length) do
    IO.puts k
    print_value v
  end

  defp columns(record) do
    record
    |> Map.keys
    |> Enum.map(fn(c) -> String.rjust(Atom.to_string(c) <> "|", 12) end)
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
    Regex.match?(~r/(van|naar)/, String.downcase record["Naam / Omschrijving"]) &&
      record["MutatieSoort"] == "Internetbankieren"
  end
end
