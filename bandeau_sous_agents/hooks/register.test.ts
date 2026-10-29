import { expect, test } from 'claude-code/testing'

import { effort, joli } from './register'

const BAND = { component: 'AbovePrompt', props: { hasSurvey: false, isWorking: true, maxRows: 4, bodyColumns: 120, scroll: { top: 0 }, view: {} } as never } as const

test('nom du modele comme la status line', async () => {
  expect(joli('claude-opus-5-5')).toBe('Opus 5.5')
  expect(joli('claude-haiku-5-5')).toBe('Haiku 5.5')
  expect(joli('haiku')).toBe('haiku')
})

test('le bandeau montre le sous-agent et son modele', async ($, on) => {
  on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: 'a1' }))
  on('ui.render', ($, e) => { const { Box } = $.ui.resolve(e); return h(Box, {}) as never })

  for (const surface of ['terminal', 'desktop'] as const) {
    const vide = await $.ui.mount({ plugin: 'bandeau-sous-agents', surface, ...BAND })
    expect(await vide.find({ type: 'Text', text: /Haiku/ })).toBeUndefined()
    await vide.unmount()
  }

  await $.agent.spawn({ prompt: 'cherche', subagentType: 'Explore' } as never)

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'bandeau-sous-agents', surface, ...BAND })
    expect(await ui.find({ type: 'Text', text: /Haiku 5\.5/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /Explore/ })).toBeDefined()
    await ui.unmount()
  }
})

test("un agent qui se reveille revient dans le bandeau", async ($, on) => {
  on('agent.spawn', () => ({ model: 'claude-sonnet-5-5', agentId: 'a2' }))
  on('ui.render', ($, e) => { const { Box } = $.ui.resolve(e); return h(Box, {}) as never })
  on('turn.complete', () => ({ text: '' }))
  on('turn.start', () => ({ turnId: 't' }) as never)

  await $.agent.spawn({ prompt: 'attends', subagentType: 'Explore' } as never)
  const montre = async () => {
    const ui = await $.ui.mount({ plugin: 'bandeau-sous-agents', surface: 'terminal', ...BAND })
    const t = await ui.find({ type: 'Text', text: /Sonnet 5\.5/ })
    await ui.unmount()
    return t !== undefined
  }
  expect(await montre()).toBe(true)

  await $.turn.complete({ agentId: 'a2', reason: 'answer', answer: 'fini' } as never)
  expect(await montre()).toBe(false)

  await $.turn.start({ agentId: 'a2', text: '' } as never)
  expect(await montre()).toBe(true)
})

test("l'effort s'ecrit tel quel, un budget en tokens", async () => {
  expect(effort('high')).toBe('high')
  expect(effort(8000)).toBe('8000 tok')
  expect(effort(undefined)).toBeUndefined()
})

test("l'effort suit le nom du modele : celui du lancement, puis celui des requetes de l'agent", async ($, on) => {
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'a3' }))
  on('ui.render', ($, e) => { const { Box } = $.ui.resolve(e); return h(Box, {}) as never })
  on('turn.step', async function* (_$, e) {
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null } as never
  })
  const texte = async (re: RegExp) => {
    const ui = await $.ui.mount({ plugin: 'bandeau-sous-agents', surface: 'terminal', ...BAND })
    const t = await ui.find({ type: 'Text', text: re })
    await ui.unmount()
    return t !== undefined
  }

  await $.agent.spawn({ prompt: 'cherche', subagentType: 'Explore', effort: 'low' } as never)
  expect(await texte(/Opus 5\.5/)).toBe(true)
  expect(await texte(/^ ?low$/)).toBe(true)

  const flux = $.turn.step({ turnId: 't', index: 0, model: 'claude-opus-5-5', effort: 'xhigh', messageCount: 1, agentId: 'a3' } as never)
  for await (const _ of flux) { /* lit le flux jusqu'au bout */ }
  expect(await texte(/^ ?xhigh$/)).toBe(true)
  expect(await texte(/^ ?low$/)).toBe(false)
})
