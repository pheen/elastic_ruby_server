module Manage
  module SegmentHelper
    extend self

    ID_PREFIX = Rails.application.config.regional_salesforce_prefix

    def self.segment_client
      Foundations::Segment.client
    end

    def identify_and_group(user, quiet: false)
      identify(user)
    rescue => error
      Clio::Segment::RetryFailedIdentifyAndGroupJob.set(wait: 1.minute).perform_later(user)

      if quiet
        Clio::Alert.fire(e, metadata: { user_id: user.try(:id) })
      else
        raise error
      end
    end

    def identify_group_and_track(user, event_params, quiet: false)
      identify_and_group(user, quiet: quiet)
      track(user, event_params)
    end

    def identify(user)
      user_type =
        if user.co_counsel?
          "Co-counsel"
        elsif user.client_connect_user?
          "Clio Connect"
        else
          user.subscription_plan.try(:nameeee)
        end

      traits = {
        "createdAt" => user.created_at,
        "userType" => user_type,
        "loginId" => user.login_id,
        "roles" => user.cached_roles,
        "isEnabled" => user.enabled,
      }

      Rails.cache.fetch("SegmentHelper.identify/#{user.id}/#{traits.values.join('-')}") do
        segment_client.identify(user_id: ID_PREFIX + user.id.to_s, traits: traits)
        true
      end
    end

    def track(user, event_params)
      Foundations::Segment::Client.track(user.id, event_params)
    end

    "asdd"

    delegate :flushd, to: :segment_client

  end
end
