/**
 * OpenTelemetry configuration for the MACU Agent App.
 * Sends traces, metrics, and logs to Application Insights.
 */
import { useAzureMonitor } from '@azure/monitor-opentelemetry';
import { trace, SpanStatusCode } from '@opentelemetry/api';
import { config } from './config.js';

let telemetryConfigured = false;

/**
 * Initialize Azure Monitor OpenTelemetry with Application Insights.
 * Must be called BEFORE importing other modules that need tracing.
 */
export function configureTelemetry() {
  if (telemetryConfigured) return;

  useAzureMonitor({
    azureMonitorExporterOptions: {
      connectionString: config.appInsightsConnectionString,
    },
  });

  telemetryConfigured = true;
  console.log('Azure Monitor OpenTelemetry configured');
}

/**
 * Get a tracer instance for creating custom spans.
 * @param {string} name - Tracer name
 * @returns {import('@opentelemetry/api').Tracer}
 */
export function getTracer(name = 'macu-agent') {
  return trace.getTracer(name);
}

export { SpanStatusCode };
