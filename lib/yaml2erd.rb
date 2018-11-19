require 'gviz'
require 'rails/all'
require 'yaml2erd/version'
require 'yaml2erd/er_yaml_parser'

class Yaml2erd
  attr_accessor :group_global_conf

  ARROW_MAP = {
    has_many: { arrowhead: 'crow', arrowtail: 'tee', arrowsize: 5, dir: 'both', minlen: 5, penwidth: 10 },
    has_one: { arrowhead: 'tee', arrowtail: 'tee', arrowsize: 5, dir: 'both', minlen: 5, penwidth: 10 }
  }.freeze

  TABLE_HEADER = %w[
    物理名
    論理名
    型
    PK
    FK
    NOT_NULL
    DEFAULT
    説明
  ].freeze

  DEFAULT_CONF = {
    global_conf: {
      layout: 'dot'
    },
    entity_conf: {
      shape: 'Mrecord',
      fontname: 'Noto Sans CJK JP Black',
      fontsize: 50
    },
    group_conf: {
      shape: 'Mrecord',
      fontname: 'Noto Sans CJK JP Black',
      fontsize: 120
    }
  }.freeze

  # TODO: nodesとglobalの違いみたいなの調査
  def initialize(yaml_file_path, conf_yaml_path)
    @yaml = ErYamlParser.new(yaml_file_path)
    @gv = Gviz.new

    apply_conf(conf_yaml_path)
  end

  def write_erd
    # entityとrelation作成
    @yaml.model_list.each do |model|
      columns = @yaml.models[model].columns
      relations = @yaml.models[model].relations
      description = @yaml.models[model].description

      validate_columns!(model, columns)

      # TODO: addとrouteの違いはなんだろう
      # entityの枠(model)作成
      @gv.route model

      # entityの中身(tableタグ)作成、適用
      table_tag = create_table_tag(model, columns, description)
      @gv.node model, label: table_tag

      # relation適用
      apply_relation(model, relations)
    end

    # group適用
    apply_grouping
  end

  def file_save(save_path: '')
    ext = :png
    dir = 'erd'
    filename = remove_ext(@yaml.yaml_file_path)

    if save_path.present?
      dir = File.dirname(save_path)
      filename = remove_ext(save_path)
      ext = File.extname(save_path).slice!(1..-1)
    end

    @gv.save "#{dir}/#{filename}", ext
  end

  private

  def apply_conf(conf_yaml_path)
    conf = DEFAULT_CONF
    custom_conf = {}
    if conf_yaml_path.present?
      File.open(conf_yaml_path) do |file|
        custom_conf = YAML.safe_load(file.read).deep_symbolize_keys
      end
    end

    # DEFAULT_CONFとキー重複しているものだけ適用
    custom_conf.each do |custom_key, custom_details|
      if conf.keys.include?(custom_key)
        custom_details.each do |custom_detail_key, custom_val|
          if conf[custom_key].keys.include?(custom_detail_key)
            conf[custom_key][custom_detail_key] = custom_val
          end
        end
      end
    end

    # 適用
    @group_global_conf = conf[:group_conf]
    @nodes_conf = conf[:entity_conf]

    @gv.global conf[:global_conf]
    @gv.nodes @nodes_conf
  end

  def validate_columns!(db_table_name, db_columns)
    # ささやかなバリデーション
    return if db_columns.class == Hash
    p "#{db_table_name} columns error"
    exit
  end

  def create_table_tag(db_table_name, db_columns, db_table_description)
    table_tag = "<table border='0' cellborder='1' cellpadding='8'>"

    # DBのテーブル名
    table_tag += "<tr><td bgcolor='lightblue' colspan='#{TABLE_HEADER.size}'>#{db_table_name}</td></tr>"
    # ヘッダ(TABLE_HEADERから生成)
    table_tag += create_table_header
    # ボディ(DBのテーブルの各カラムのデータ)
    table_tag += create_table_body(db_columns)
    # フッタ
    table_tag += "<tr><td bgcolor='lightblue' colspan='#{TABLE_HEADER.size}'>#{nl2br(db_table_description)}</td></tr>"

    table_tag += '</table>'
    table_tag
  end

  def create_table_header
    table_header = '<tr>'
    TABLE_HEADER.each do |head|
      table_header += "<td bgcolor='lightblue'>#{head}</td>"
    end
    table_header += '</tr>'
    table_header
  end

  def create_table_body(db_columns)
    table_body = ''
    db_columns.each do |db_column, db_column_info|
      db_column_logical_name = db_column_info[:logical_name].presence || ''
      db_column_description = db_column_info[:description].presence || ''
      db_column_options = db_column_info[:options].presence || {}

      # 表示する値とalignの指定
      table_columns = [
        { val: db_column,                                             align: :left },
        { val: db_column_logical_name,                                align: :left },
        { val: db_column_info[:type],                                 align: :left },
        { val: convert_check_mark(db_column_options[:primary_key]),   align: :center },
        { val: convert_check_mark(db_column_options[:foreign_key]),   align: :center },
        { val: convert_check_mark(db_column_options[:not_null]),      align: :center },
        { val: db_column_options[:default],                           align: :left },
        { val: nl2br(db_column_description),                          align: :left }
      ]

      table_body += create_table_line(table_columns)
    end
    table_body
  end

  def convert_check_mark(val)
    # TODO: 指定なし/指定ありtrue/指定ありfalseを考慮
    val.present? ? '✔︎' : ''
  end

  def nl2br(str)
    str.gsub(/\r\n|\r|\n/, '<br />')
  end

  def create_table_line(table_columns)
    table_line = '<tr>'
    table_columns.each do |table_column|
      table_line += "<td bgcolor='white' align='#{table_column[:align]}'>#{table_column[:val]}</td>" \
    end
    table_line += '</tr>'
    table_line
  end

  def apply_relation(model, relations)
    # リレーションのマッピング
    return if relations.blank?
    relations.each do |relation|
      relation.each do |rel_type, rel_model|
        next if rel_type == :belongs_to
        @gv.edge "#{model}_#{rel_model}", ARROW_MAP[rel_type]
      end
    end
  end

  def apply_grouping
    # グループ内に適用するために再度@nodes_confをあてる
    nodes_conf = @nodes_conf
    group_conf = @group_global_conf

    # mapをもとにグルーピング
    @yaml.groups_map.each do |group_name, models|
      group_bgcolor = @yaml.groups_bgcolor_map[group_name.to_sym]

      @gv.subgraph do
        global group_conf.merge(label: group_name, bgcolor: group_bgcolor)
        nodes nodes_conf
        # model割り当て
        models.each do |model|
          node model
        end
      end
    end
  end

  def remove_ext(file_name)
    File.basename(file_name, '.*')
  end
end
