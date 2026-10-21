import { expect, test } from 'claude-code/testing'

import { joli } from './register'

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
    const vide = await $.ui.mount({ plugin: 'modele-agents', surface, ...BAND })
    expect(await vide.find({ type: 'Text', text: /Haiku/ })).toBeUndefined()
    await vide.unmount()
  }

  await $.agent.spawn({ prompt: 'cherche', subagentType: 'Explore' } as never)

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'modele-agents', surface, ...BAND })
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
    const ui = await $.ui.mount({ plugin: 'modele-agents', surface: 'terminal', ...BAND })
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
