defmodule BankTest do
  use ExUnit.Case
  doctest Bank

  test "#read_csv removes same account transactions" do
    transactions_csv = "./test/fixtures/ing.csv"
    records = Bank.read_csv(transactions_csv) |> Enum.to_list
    assert Enum.count(records) == 6
  end

  test "#supermarkets counts expenses for supermarkets" do
    transactions_csv = "./test/fixtures/ing.csv"
    assert Bank.supermarkets(transactions_csv) == 55.00
  end
end
