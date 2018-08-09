#
# Cookbook Name :: solrcloud
# Recipe :: custom_metrics.rb
#
# This recipe adds custom handler metrics to the default jmx metrics file. Custom solr-handlers JMX mbeans can be specified for reporting to telegraf in addition
# to default metrics. Example of custom_metric_yaml field value in OneOps can be:
# 'category=QUERY,scope=/select/level1_en,name=requestTimes:
#       - Count
#       - OneMinuteRate
#       - FiveMinuteRate
#       - FifteenMinuteRate'
#
require 'yaml'
include_recipe 'solrcloud::default'

ruby_block 'adding custom yaml metrics' do
  # Custom YAML metric string from OneOps UI
  yaml_string = node["custom_metric_yaml"]

  #Check if string is in valid YAML format
  custom_metric_yaml = YAML.load(yaml_string)

  if custom_metric_yaml.class != Hash then
    Chef::Log.error("Unable to parse the custom YAML string as a valid YAML: #{yaml_string}")
  else
    #Trim any spaces in custom YAML string
    trimmed_custom_yaml = Hash.new
    trimmed_hash = Hash.new
    custom_metric_yaml.each do |k,v|
      value = v
      if value.is_a?(Hash)
        value.each do |k,v|
          new_key = k.delete(' ')
          if v.is_a?(Array)
            v.each { |x| x.delete!(' ')}
          end
          trimmed_hash[new_key] = v
        end
      end
      trimmed_custom_yaml[k] = trimmed_hash
    end
  end

  # Loads the default yaml file stored in the node based on solr version and merge both the yaml hashes
  # Replace default yaml file with merged yaml file
  block do
    # Merge method by default overwrites hash values  if the key matches.
    # In order to prevent that, deep merge can be performed and both hash values are merged and assigned to the same key
    merger = proc do |key,v1,v2|
      Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2
    end
    if node['solr_version'].start_with? "7."
      default_metrics_yaml = YAML.load_file(File.join('/opt/solr/solrmonitor/metrics','jmx_metrics_7.2.1.yml'))
      default_metrics_yaml.merge!(trimmed_custom_yaml, &merger)
      File.open("/opt/solr/solrmonitor/metrics/jmx_metrics_7.2.1.yml", "w") { |file| file.write(default_metrics_yaml.to_yaml)}

    elsif (node['solr_version'] =~ /^6\.[4-9]/)
      default_metrics_yaml = YAML.load_file(File.join('/opt/solr/solrmonitor/metrics', 'jmx_metrics_6_higher_x.yml'))
      default_metrics_yaml.merge!(trimmed_custom_yaml, &merger)
      File.open("/opt/solr/solrmonitor/metrics/jmx_metrics_6_higher_x.yml", "w") { |file| file.write(default_metrics_yaml.to_yaml)}

    elsif (node['solr_version'] =~ /^6\.[0-3]/)
      default_metrics_yaml = YAML.load_file(File.join('/opt/solr/solrmonitor/metrics','jmx_metrics_6_lower_x.yml'))
      default_metrics_yaml.merge!(trimmed_custom_yaml, &merger)
      File.open("/opt/solr/solrmonitor/metrics/jmx_metrics_6_lower_x.yml", "w") { |file| file.write(default_metrics_yaml.to_yaml)}
    end
  end
end