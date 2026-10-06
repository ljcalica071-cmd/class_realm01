import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import nodemailer from "npm:nodemailer"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to, subject, html } = await req.json()

    if (!to || !subject || !html) {
      throw new Error('Missing required fields: to, subject, or html')
    }

    const SMTP_HOSTNAME = Deno.env.get('SMTP_HOSTNAME') ?? 'smtp.gmail.com'
    const SMTP_PORT = parseInt(Deno.env.get('SMTP_PORT') ?? '465')
    const SMTP_USERNAME = Deno.env.get('SMTP_USERNAME')
    const SMTP_PASSWORD = Deno.env.get('SMTP_PASSWORD')

    if (!SMTP_USERNAME || !SMTP_PASSWORD) {
      throw new Error('SMTP credentials not configured in environment variables')
    }

    const transporter = nodemailer.createTransport({
      host: SMTP_HOSTNAME,
      port: SMTP_PORT,
      secure: SMTP_PORT === 465,
      auth: {
        user: SMTP_USERNAME,
        pass: SMTP_PASSWORD,
      },
    })

    const info = await transporter.sendMail({
      from: `"ClassRealm Admin" <${SMTP_USERNAME}>`,
      to: to,
      subject: subject,
      html: html,
    })

    return new Response(
      JSON.stringify({ message: 'Email sent successfully!', info: info.messageId }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
