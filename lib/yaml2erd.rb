require 'gviz'
require 'active_support/all'
require 'yaml2erd/version'
require 'yaml2erd/er_yaml_parser'
require 'yaml2erd/gv_id_map'

class Yaml2erd
  attr_accessor :group_global_conf

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

  CUSTOMIZABLE_CONF = {
    global_conf: {
      layout: 'fdp',
      splines: 'ortho',
      K: 5
    },
    entity_conf: {
      shape: 'Mrecord',
      fontname: 'Noto Sans CJK JP Black',
      fontsize: 20
    },
    group_conf: {
      shape: 'Mrecord',
      fontname: 'Noto Sans CJK JP Black',
      fontsize: 40
    },
    arrow_map: {
      has_many: { arrowsize: 3, penwidth: 4, len: 10 },
      has_one: { arrowsize: 3, penwidth: 4, len: 10 }
    }
  }.freeze

  NOT_CUSTOMIZABLE_CONF = {
    global_conf: {
      overlap: false,
      sep: '+1'
    },
    arrow_map: {
      has_many: { arrowhead: 'crow', arrowtail: 'tee', dir: 'both' },
      has_one: { arrowhead: 'tee', arrowtail: 'tee', dir: 'both' }
    }
  }.freeze

  # TODO: nodesとglobalの違いみたいなの調査
  def initialize(yaml_file_path, conf_yaml_path)
    @yaml = ErYamlParser.new(yaml_file_path)
    @gv = Gviz.new
    @gv_id_map = GvIdMap.new

    @customized_conf = fetch_conf(conf_yaml_path)
    apply_conf(@customized_conf)
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
      @gv.route @gv_id_map.enc(model)

      # entityの中身(tableタグ)作成、適用
      table_tag = create_table_tag(model, columns, description)
      @gv.node @gv_id_map.enc(model), label: table_tag

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

  def fetch_conf(conf_yaml_path)
    user_conf = {}
    if conf_yaml_path.present?
      File.open(conf_yaml_path) do |file|
        user_conf = YAML.safe_load(file.read).deep_symbolize_keys
      end
    end

    # CUSTOMIZABLE_CONFとキー重複しているものだけ適用
    customized_conf = merge_keep_struct(CUSTOMIZABLE_CONF.dup, user_conf)

    # ユーザ設定取り込んで、固定値をマージして返す
    customized_conf.deep_merge(NOT_CUSTOMIZABLE_CONF)
  end

  def merge_keep_struct(base_hash, input_hash)
    input_hash.each do |key, val|
      # input_hashのネストが深すぎる時にエラーになるからtry
      next unless base_hash.try(:keys).try(:include?, key)

      if val.is_a?(Hash)
        base_hash[key] = merge_keep_struct(base_hash[key], input_hash[key])
      else
        # input_hashのネストが浅すぎる時(inputは底までついたけどbaseはまだhashの時)はスルーするように
        next if base_hash[key].is_a?(Hash)
        base_hash[key] = val
      end
    end
    base_hash
  end

  def apply_conf(conf)
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
        next if rel_type != :has_one && rel_type != :has_many
        @gv.edge "#{@gv_id_map.enc(model)}_#{@gv_id_map.enc(rel_model)}", @customized_conf[:arrow_map][rel_type]
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
      alias_models = models.map do |model| @gv_id_map.enc(model) end

      @gv.subgraph do
        global group_conf.merge(label: group_name, bgcolor: group_bgcolor)
        nodes nodes_conf
        # model割り当て
        alias_models.each do |alias_model|
          node alias_model
        end
      end
    end
  end

  def remove_ext(file_name)
    File.basename(file_name, '.*')
  end
end
