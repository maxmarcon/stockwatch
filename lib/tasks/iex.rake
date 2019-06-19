namespace :iex do
  desc "Initialize the iex symbols"
  task init: :environment do
    prompt = TTY::Prompt.new

    if IexSymbol.none? || prompt.yes?("There are already Iex symbols present. Really refetch all symbols?")
      IexService.new.init_symbols
      prompt.ok("There are now #{IexSymbol.count} symbols")
    end
  end

  desc "Delete all iex symbols"
  task delete: :environment do
    prompt = TTY::Prompt.new

    unless prompt.no?("This will delete all Iex symbols. Are you sure?")
      IexService.new.delete_symbols
      prompt.ok("All symbols were deleted")
    end
  end
end
