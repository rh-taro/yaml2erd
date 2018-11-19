class ErYamlModel
  def initialize(yaml_model)
    @yaml_model = yaml_model

    parse_columns
  end

  def columns
    @yaml_model[:columns]
  end

  def parsed_columns
    @yaml_model[:parsed_columns]
  end

  def relations
    # TODO: 同じassociationのtypeまとめる形の方がいいかも yamlの構造を変えるかここで変換するか
    @yaml_model[:relations]
  end

  def group_name
    @yaml_model[:group]
  end

  def description
    @yaml_model[:description]
  end

  private

  def parse_columns
    @yaml_model[:parsed_columns] = @yaml_model[:columns].map do |column|
      { column_name: column[0], column_detail: column[1] }
    end
  end
end
