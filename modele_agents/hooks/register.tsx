import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Agent } from '../types'

// Tous les agents lances, gardes pour retrouver le modele d'un agent qui se reveille
const known = atom({ plugin: 'modele-agents', key: 'known' } as const, {} as Record<string, Agent>)
const running = atom({ plugin: 'modele-agents', key: 'running' } as const, {} as Record<string, Agent>)

// claude-opus-5-5 -> Opus 5.5, comme le display_name de la status line
export const joli = (model: string): string => {
  const [, nom, majeur, mineur] = /^claude-([a-z]+)-(\d+)-(\d+)/.exec(model) ?? []
  if (!nom) return model
  return `${nom.charAt(0).toUpperCase()}${nom.slice(1)} ${majeur}.${mineur}`
}

export const register: Register = on => {
  on('agent.spawn', async ($, e, next) => {
    const res = await next(e)
    const id = 'agentId' in res ? res.agentId : undefined
    if (id) {
      const agent: Agent = { type: e.subagentType || 'agent', model: joli(('model' in res && res.model) || '?') }
      await update($, known, all => ({ ...all, [id]: agent }))
      await update($, running, all => ({ ...all, [id]: agent }))
    }
    return res
  })

  // Un agent qui avait rendu la main repart (fin d'une commande en arriere-plan, message)
  on('turn.start', async ($, e, next) => {
    const id = e.agentId
    const agent = id ? (await read($, known))[id] : undefined
    if (id && agent) {
      await update($, running, all => (all[id] ? all : { ...all, [id]: agent }))
    }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const id = e.agentId
    if (id) {
      await update($, running, all => {
        const { [id]: _, ...rest } = all
        return rest
      })
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const agents = Object.values(await read($, running))
    if (e.props.hasSurvey || agents.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box>
        {agents.map((a, i) => (
          <Text key={String(i)}>
            {i > 0 ? <Text dimColor> | </Text> : null}
            {a.type}<Text dimColor>·</Text><Text color="cyan">{a.model}</Text>
          </Text>
        ))}
      </Box>
    )
  })
}
