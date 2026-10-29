export type Agent = { type: string; model: string; effort?: string }

declare module 'claude-code' {
  interface PluginState {
    'bandeau-sous-agents': { known: Record<string, Agent>; running: Record<string, Agent> }
  }
}
