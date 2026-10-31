class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params[:plan_addons] = plan_addons_param if params.dig(:account, :plan_addons).present?
    permitted_params
  end

  def renew_plan
    # rubocop:disable Rails/I18nLocaleTexts
    return redirect_back(fallback_location: [namespace, requested_resource], alert: 'Assign a plan to this account first') if requested_resource.plan.nil?

    requested_resource.renew_plan!
    redirect_back(fallback_location: [namespace, requested_resource],
                  notice: "Plan active until #{requested_resource.plan_ends_at.in_time_zone(Plan::TIMEZONE).strftime('%d %b %Y, %I:%M %p')}")
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def add_plan_pack
    key = params[:pack_key].to_s
    amount = params[:pack_amount].to_i
    # rubocop:disable Rails/I18nLocaleTexts
    unless Plan::CYCLE_KEYS.include?(key) && amount.positive?
      return redirect_back(fallback_location: [namespace, requested_resource], alert: 'Choose a limit and a positive amount')
    end

    requested_resource.add_plan_pack!(key, amount)
    redirect_back(fallback_location: [namespace, requested_resource], notice: "Added #{amount} #{PlanLimitsField.label(key)} for this month")
    # rubocop:enable Rails/I18nLocaleTexts
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  # Only the "every month" add-ons come from the form; packs are kept as they are.
  def plan_addons_param
    recurring = params[:account][:plan_addons].permit(recurring: {}).to_h.fetch('recurring', {})
    recurring = recurring.select { |_key, value| value.to_s.match?(/\A\d+\z/) && value.to_i.positive? }.transform_values(&:to_i)
    existing = action_name == 'update' ? requested_resource.plan_addons.to_h : {}
    existing.merge('recurring' => recurring)
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
