require "yaml"

task :fetch do
  yaml = YAML.load(File.read("libraries.yml"))
  yaml.each do |name, properties|
    puts ">>> Fetching #{name}"
    if url = properties["url"]
      `curl -L #{url} > vendor/#{File.basename(url)}`
    end
  end
end
