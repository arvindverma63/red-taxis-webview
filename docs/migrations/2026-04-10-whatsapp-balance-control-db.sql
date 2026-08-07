-- WhatsApp Dispatch Multi-Tenant: Control DB Migration
-- Run against: redtaxi_control (both local dev and Railway production)
-- Date: 2026-04-10
-- Feature: whatsapp-multi-tenant
--
-- Adds whatsapp_balance to the organization table and
-- whatsapp_messages_limit to the plans table.
-- Both use IF NOT EXISTS to be safely re-runnable.

-- 1. Add whatsapp_balance to organization table (metering per tenant)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'organization' AND column_name = 'whatsapp_balance'
    ) THEN
        ALTER TABLE organization ADD COLUMN whatsapp_balance INTEGER NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added whatsapp_balance column to organization table';
    ELSE
        RAISE NOTICE 'whatsapp_balance column already exists on organization table';
    END IF;
END $$;

-- 2. Add whatsapp_messages_limit to plans table (plan-level quota)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'plans' AND column_name = 'whatsapp_messages_limit'
    ) THEN
        ALTER TABLE plans ADD COLUMN whatsapp_messages_limit INTEGER NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added whatsapp_messages_limit column to plans table';
    ELSE
        RAISE NOTICE 'whatsapp_messages_limit column already exists on plans table';
    END IF;
END $$;

-- 3. Set default WhatsApp credits for existing plans (match SMS pattern)
-- Plan names: Solo=50, Team=150, Fleet=300, Enterprise=500
UPDATE plans SET whatsapp_messages_limit = 50  WHERE name = 'Solo'       AND whatsapp_messages_limit = 0;
UPDATE plans SET whatsapp_messages_limit = 150 WHERE name = 'Team'       AND whatsapp_messages_limit = 0;
UPDATE plans SET whatsapp_messages_limit = 300 WHERE name = 'Fleet'      AND whatsapp_messages_limit = 0;
UPDATE plans SET whatsapp_messages_limit = 500 WHERE name = 'Enterprise' AND whatsapp_messages_limit = 0;

-- 4. Seed existing tenants with initial WhatsApp balance from their plan
UPDATE organization o
SET whatsapp_balance = COALESCE(
    (SELECT p.whatsapp_messages_limit FROM plans p WHERE p.id = o.plan_id),
    0
)
WHERE o.whatsapp_balance = 0;
