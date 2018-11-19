class GvIdMap
  def initialize
    @map = {}
    @cnt = 1
  end

  def enc(model)
    model = model.to_sym if model.class == String

    if @map[model].nil?
      @map[model] = @cnt.to_s.to_sym
      @cnt += 1
    end

    @map[model]
  end
end
