require 'yaml'
require 'active_support/all'
require 'yaml2erd/er_yaml_model'

class ErYamlParser
  attr_reader :yaml_file_path
  attr_reader :models
  attr_reader :groups
  attr_reader :model_list
  attr_reader :groups_map
  attr_reader :groups_bgcolor_map

  def initialize(yaml_file_path)
    @yaml_file_path = yaml_file_path

    # yamlファイルopen
    set_yaml_data
    # modelのリスト
    set_model_list
    # YamlModelのハッシュ
    set_models
    # groups
    set_groups
    # groups_map
    set_groups_map
    # groups_bgcolor_map
    set_groups_bgcolor_map
  end

  private

  def set_yaml_data
    File.open(@yaml_file_path) do |file|
      @yaml_data = YAML.safe_load(file.read).deep_symbolize_keys
    end
  end

  def set_model_list
    @model_list = @yaml_data[:models].map do |h| h[0] end
  end

  def set_models
    @models = {}
    @model_list.each do |model_name|
      @models[model_name] = ErYamlModel.new(@yaml_data[:models][model_name])
    end
  end

  def set_groups
    @groups = @yaml_data[:groups]
  end

  # グルーピングのmap作成
  def set_groups_map
    @groups_map = {}
    @model_list.each do |model|
      next if @models[model].group_name.blank?

      group_name = @models[model].group_name.to_sym

      # なければ初期化
      @groups_map[group_name] = [] if @groups_map[group_name].blank?
      @groups_map[group_name] << model
    end
  end
  # TODO: 複数指定で重ねたり、入れ子にしたりできるように
  # {:group_name => [table_name1, ...]}というhashを作る

  def set_groups_bgcolor_map
    @groups_bgcolor_map = {}
    @groups.each do |group|
      @groups_bgcolor_map[group[:name].to_sym] = group[:bgcolor]
    end
  end
end
