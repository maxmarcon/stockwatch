namespace :figi do

  desc "Retrieve or update FIGIs by ISIN"
  task :update, [:isins] => [:environment] do |task, args|
    prompt = TTY::Prompt.new

    if args.any?
      FigiService.new({'api_service' => {'call_max_age' => 1}}).index_by_isin(args.to_a).each do |isin, figis|
        prompt.say "#{isin}: found #{figis.count} isins"
      end
    else
      prompt.error "Please specify a comma separated list of ISINs"
    end
  end

  desc "Delete FIGIs by ISIN (pass 'all' to remove all FIGIs)"
  task :delete, [:isins] => [:environment] do |task, args|
    prompt = TTY::Prompt.new

    if args.any?
      if args.isins == 'all'
        FigiService.new.delete_all
        prompt.ok "All FIGI entries were deleted"
      else
        FigiService.new.delete_by_isin(args.to_a)
        prompt.ok "The requested FIGI entries were deleted"
      end
    else
      prompt.error "Please specify a comma separated list of ISINs or 'all'"
    end
  end
end
