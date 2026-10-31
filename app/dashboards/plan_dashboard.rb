require 'administrate/base_dashboard'

class PlanDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String.with_options(searchable: true),
    price: Field::Number.with_options(prefix: 'Rs ', multiplier: 1),
    duration_days: Field::Number,
    limits: PlanLimitsField,
    active: Field::Boolean,
    accounts: CountField,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id name price duration_days active accounts].freeze

  SHOW_PAGE_ATTRIBUTES = %i[id name price duration_days active limits accounts created_at updated_at].freeze

  FORM_ATTRIBUTES = %i[name price duration_days active limits].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(plan)
    "#{plan.name} (Rs #{plan.price} / #{plan.duration_days} days)"
  end
end
