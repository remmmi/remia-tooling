import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Agent } from '../types'

// Tous les agents lances, gardes pour retrouver le modele d'un agent qui se reveille
const known = atom({ plugin: 'bandeau-sous-agents', key: 'known' } as const, {} as Record<string, Agent>)
const running = atom({ plugin: 'bandeau-sous-agents', key: 'running' } as const, {} as Record<string, Agent>)

// claude-opus-5-5 -> Opus 5.5, comme le display_name de la status line
export const joli = (model: string): string => {
  const [, nom, majeur, mineur] = /^claude-([a-z]+)-(\d+)-(\d+)/.exec(model) ?? []
  if (!nom) return model
  return `${nom.charAt(0).toUpperCase()}${nom.slice(1)} ${majeur}.${mineur}`
}

// Un niveau (high) tel quel, un budget entier en tokens (8000 -> 8000 tok)
export const effort = (v: string | number | undefined): string | undefined =>
  v === undefined || v === '' ? undefined : typeof v === 'number' ? `${v} tok` : v

const noteEffort = (all: Record<string, Agent>, id: string, e: string): Record<string, Agent> =>
  all[id] && all[id].effort !== e ? { ...all, [id]: { ...all[id], effort: e } } : all

export const register: Register = on => {
  on('agent.spawn', async ($, e, next) => {
    const res = await next(e)
    const id = 'agentId' in res ? res.agentId : undefined
    if (id) {
      const agent: Agent = {
        type: e.subagentType || 'agent',
        model: joli(('model' in res && res.model) || '?'),
        effort: effort(e.effort),
      }
      await update($, known, all => ({ ...all, [id]: agent }))
      await update($, running, all => ({ ...all, [id]: agent }))
    }
    return res
  })

  // L'effort reel d'un agent : celui de chaque requete de sa boucle (reglage du type, de la session ou defaut du modele)
  on('turn.step', async function* ($, e, next) {
    const id = e.agentId
    const niveau = effort(e.effort)
    if (id && niveau) {
      await update($, known, all => noteEffort(all, id, niveau))
      await update($, running, all => noteEffort(all, id, niveau))
    }
    return yield* next(e)
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
            {a.effort ? <Text dimColor> {a.effort}</Text> : null}
          </Text>
        ))}
      </Box>
    )
  })
}
