require 'administrate/field/base'

# Extra limits for one account on top of its plan.
# recurring: added every month until removed. packs: added for one monthly cycle only.
class PlanAddonsField < Administrate::Field::Base
  def recurring
    (data.presence || {}).to_h.fetch('recurring', {})
  end

  def packs
    (data.presence || {}).to_h.fetch('packs', {})
  end

  def to_s
    recurring.map { |key, value| "#{PlanLimitsField.label(key)}: +#{value}" }.join(', ')
  end
end
