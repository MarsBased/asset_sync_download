namespace :assets do
  namespace :sync do

    desc "Download a manifest and asset files"
    task :download => :environment do
      Rake::Task["assets:sync:download:manifest"].invoke
      Rake::Task["assets:sync:download:asset_files"].invoke

      if AssetSyncDownload.webpacker_enabled?
        Rake::Task["assets:sync:download:webpacker_manifest"].invoke
        Rake::Task["assets:sync:download:webpacker_asset_files"].invoke
      end
    end

    namespace :download do

      desc "Download a manifest"
      task :manifest => :environment do
        AssetSyncDownload.download(:manifest)
      end

      desc "Download asset files"
      task :asset_files => :environment do
        AssetSyncDownload.download(:asset_files)
      end

      desc "Download a Webpacker manifest"
      task :webpacker_manifest => :environment do
        AssetSyncDownload.download(:webpacker_manifest)
      end

      desc "Download Webpacker files"
      task :webpacker_asset_files => :environment do
        AssetSyncDownload.download(:webpacker_asset_files)
      end

    end
  end

end
