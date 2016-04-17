defmodule BankTest do
  use ExUnit.Case
  doctest Bank

  
  setup do
    transactions_csv = "./test/fixtures/ing.csv"
    records = Bank.read_csv(transactions_csv)
    {:ok, records: records}
  end

  test "#read_csv removes same account transactions", context do
    assert Enum.count(context[:records]) == 6
  end

  test "#add_year add new field :year", context do
    records = Bank.add_year(context[:records]) #|> Enum.to_list
    assert Enum.all?(records, fn(x) -> Map.has_key?(x, :year) end) == true
  end

  test "#add_month add new field :month", context do
    records = Bank.add_month(context[:records]) #|> Enum.to_list
    assert Enum.all?(records, fn(x) -> Map.has_key?(x, :month) end) == true
  end

  test "#is_income? detects income" do
    income = %{"Af Bij" => "Bij", "Bedrag (EUR)" => "100"}
    expense = %{"Af Bij" => "Af", "Bedrag (EUR)" => "50"}
    assert Bank.is_income?(income) == true
    assert Bank.is_income?(expense) == false
  end
  test "#is_expense? detects expense" do
    income = %{"Af Bij" => "Bij", "Bedrag (EUR)" => "100"}
    expense = %{"Af Bij" => "Af", "Bedrag (EUR)" => "50"}
    assert Bank.is_expense?(expense) == true
    assert Bank.is_expense?(income) == false
  end

  test "#calculate_totals calculates sums", context do
    records = [
      %{"Af Bij" => "Bij", "Bedrag (EUR)" => "100,00"},
      %{"Af Bij" => "Af", "Bedrag (EUR)" => "50,00"}
    ]
    sums = Bank.calculate_totals(records)
    assert sums == %{income: 100, expense: 50, savings: 50}
  end

  test "#group_by_year groups by year" do
    records = [
      %{"Af Bij" => "Bij", "Datum" => "20151231", year: 2015},
      %{"Af Bij" => "Af", "Datum" => "20151230", year: 2015}
    ]
    by_year = Bank.group_by_year(records)
    assert Map.keys(by_year) == [2015]
  end

  test "#group_by_month groups by month" do
    records = [
      %{"Af Bij" => "Bij", "Datum" => "20151231", month: 2},
      %{"Af Bij" => "Af", "Datum" => "20151230", month: 2}
    ]
    by_month = Bank.group_by_month(records)
    assert Map.keys(by_month) == [2]
  end

  test "group into year and then month" do
    records = [
      %{"Af Bij" => "Bij", "Datum" => "20151231", month: 12, year: 2015},
      %{"Af Bij" => "Af", "Datum" => "20151230", month: 11, year: 2015}
    ]

    result = Bank.group_by_year_and_month(records)
    assert result == %{2015 =>
                        %{
                          12 => [ List.first(records) ],
                          11 => [ List.last(records) ]
                        }
                      }
  end
  # test "#supermarkets counts expenses for supermarkets" do
  #   transactions_csv = "./test/fixtures/ing.csv"
  #   assert Bank.supermarkets(transactions_csv) == 55.00
  # end
end
