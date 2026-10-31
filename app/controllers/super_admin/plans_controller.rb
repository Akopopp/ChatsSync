class SuperAdmin::PlansController < SuperAdmin::ApplicationController
  def resource_params
    permitted = params.require(:plan).permit(:name, :price, :duration_days, :active, limits: {})
    permitted[:limits] = permitted[:limits].to_h.merge(extra_limits)
    permitted
  end

  private

  # "broadcast_lists=5" lines from the form become extra limit keys
  def extra_limits
    params.dig(:plan, :limits_extra).to_s.lines.each_with_object({}) do |line, result|
      key, value = line.split('=', 2).map { |part| part.to_s.strip }
      result[key.parameterize(separator: '_')] = value if key.present?
    end
  end
end
