namespace :iex do
  desc "Initialize the iex symbols"
  task init: :environment do
    prompt = TTY::Prompt.new

    if IexSymbol.none? || prompt.yes?("There are already Iex symbols present. Really refetch all symbols?")
      IexService.new({'api_service' => {'call_max_age' => 1}}).init_symbols
      prompt.ok("There are now #{IexSymbol.count} symbols")
    end
  end

  task :fetch, [:refs] => [:environment] do |task, args|
    prompt = TTY::Prompt.new

    if (args.none?)
      prompt.error "You need to specify one or more references to fetch"
    else
      refs = args.to_a
        .map{ |ref| if ref.start_with?('ref-data') then ref else "ref-data/#{ref}" end }
        .map{ |ref| if ref.end_with?('symbols') then ref else "#{ref}/symbols" end }

      prompt.say("Fetching symbols from the following lists:")
      refs.each{ |ref| prompt.say(ref) }

      if prompt.yes?("Continue?")
        IexService.new({'api_service' => {'call_max_age' => 1}, 'symbol_lists' => refs}).init_symbols
        prompt.ok("There are now #{IexSymbol.count} symbols")
      end
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
