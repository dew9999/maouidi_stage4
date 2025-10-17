// supabase/functions/send-notification/index.ts

import { createClient } from '@supabase/supabase-js'
import { serve } from 'std/http/server.ts'

const ONE_SIGNAL_APP_ID = Deno.env.get('ONE_SIGNAL_APP_ID')!
const ONE_SIGNAL_API_KEY = Deno.env.get('ONE_SIGNAL_API_KEY')!

// Define the structure for our multilingual notifications
interface NotificationContent {
  headings: { [language: string]: string };
  contents: { [language: string]: string };
}

// Central repository for all notification translations
const notifications: Record<string, NotificationContent> = {
  NEW_BOOKING: {
    headings: {
      en: 'New Booking Request',
      ar: 'طلب حجز جديد',
      fr: 'Nouvelle demande de réservation',
    },
    contents: {
      en: '{patient_name} has requested an appointment.',
      ar: 'طلب {patient_name} موعدًا.',
      fr: '{patient_name} a demandé un rendez-vous.',
    },
  },
  APPOINTMENT_CONFIRMED: {
    headings: {
      en: 'Appointment Confirmed!',
      ar: 'تم تأكيد الموعد!',
      fr: 'Rendez-vous confirmé !',
    },
    contents: {
      en: 'Your appointment with {partner_name} on {appointment_time} is confirmed.',
      ar: 'تم تأكيد موعدك مع {partner_name} في {appointment_time}.',
      fr: 'Votre rendez-vous avec {partner_name} le {appointment_time} est confirmé.',
    },
  },
  APPOINTMENT_CANCELLED_BY_PARTNER: {
    headings: {
      en: 'Appointment Canceled',
      ar: 'تم إلغاء الموعد',
      fr: 'Rendez-vous annulé',
    },
    contents: {
      en: 'Unfortunately, your appointment with {partner_name} on {appointment_time} has been canceled.',
      ar: 'للأسف، تم إلغاء موعدك مع {partner_name} في {appointment_time}.',
      fr: 'Malheureusement, votre rendez-vous avec {partner_name} le {appointment_time} a été annulé.',
    },
  },
  APPOINTMENT_CANCELLED_BY_USER: {
    headings: {
      en: 'Booking Canceled',
      ar: 'تم إلغاء الحجز',
      fr: 'Réservation annulée',
    },
    contents: {
      en: '{patient_name} has canceled their appointment for {appointment_time}.',
      ar: 'لقد ألغى {patient_name} موعده في {appointment_time}.',
      fr: '{patient_name} a annulé son rendez-vous pour le {appointment_time}.',
    },
  },
};

// Helper function to replace placeholders like {patient_name}
function interpolate(text: string, data: Record<string, string>): string {
  return text.replace(/\{(\w+)\}/g, (placeholder, key) => {
    return data[key] || placeholder;
  });
}

serve(async (req: Request) => {
  try {
    const { recipient_user_id, notification_type, data } = await req.json();

    if (!notification_type || !notifications[notification_type]) {
      throw new Error(`Invalid notification type: ${notification_type}`);
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    let playerId: string | null = null;
    let notificationsEnabled = true;

    const { data: userData } = await supabaseAdmin
      .from('users')
      .select('onesignal_player_id, notifications_enabled')
      .eq('id', recipient_user_id)
      .single();
    
    if (userData && userData.onesignal_player_id) {
        playerId = userData.onesignal_player_id;
        notificationsEnabled = userData.notifications_enabled ?? true;
    } else {
        const { data: partnerData } = await supabaseAdmin
            .from('medical_partners')
            .select('onesignal_player_id, notifications_enabled')
            .eq('id', recipient_user_id)
            .single();

        if (partnerData && partnerData.onesignal_player_id) {
            playerId = partnerData.onesignal_player_id;
            notificationsEnabled = partnerData.notifications_enabled ?? true;
        }
    }


    if (playerId && notificationsEnabled) {
      const template = notifications[notification_type];
      
      const headings = template.headings;
      const contents: { [key: string]: string } = {};
      for (const lang in template.contents) {
        contents[lang] = interpolate(template.contents[lang], data);
      }

      await fetch('https://onesignal.com/api/v1/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${ONE_SIGNAL_API_KEY}`,
        },
        body: JSON.stringify({
          app_id: ONE_SIGNAL_APP_ID,
          include_player_ids: [playerId],
          headings: headings,
          contents: contents,
        }),
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error sending notification:', error);
    // MODIFICATION: Check if the error is an instance of Error before accessing .message
    if (error instanceof Error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({ error: 'An unknown error occurred.' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});