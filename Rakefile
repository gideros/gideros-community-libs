require "yaml"

task :fetch do
  yaml = YAML.load(File.read("libraries.yml"))
  only = ENV["only"]
  yaml.each do |name, properties|
    next if only && name != only
    puts ">>> Fetching #{name}"
    url = properties["url"]
    if !properties["files"]
      `curl -L #{url} > vendor/#{File.basename(url)}`
    else
      files = properties["files"]
      files.each do |file|
        puts ">>>>> Fetching #{name}/#{file}"
        target_file = "vendor/#{name}/#{file}"
        FileUtils.mkdir_p(File.dirname(target_file))
        `curl -L #{url}/#{file} > #{target_file}`
      end
    end
  end
end
