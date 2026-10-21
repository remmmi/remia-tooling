export type Agent = { type: string; model: string }

declare module 'claude-code' {
  interface PluginState {
    'modele-agents': { known: Record<string, Agent>; running: Record<string, Agent> }
  }
}
