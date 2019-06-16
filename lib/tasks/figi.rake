namespace :figi do

  desc "Retrieve or update FIGIs by ISIN"
  task :update, [:isins] => [:environment] do |task, args|
    FigiService.new.get_by_isin(args.to_a)
  end

  desc "Delete FIGIs by ISIN (don't pass any isins to remove all FIGIs)"
  task :delete, [:isins] => [:environment] do |task, args|

    if args.to_a.empty?
      FigiService.new.delete_all
    else
      FigiService.new.delete_by_isin(args.to_a)
    end
  end
end
