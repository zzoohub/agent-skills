# Text-bearing components

React Native's constraint on components that mix a container with text (buttons, chips, rows). Component APIs and a complete `Button` come from the design-system capability, if available.

**Default.** Only a text component (a `*Text` part that renders `<Text>`) accepts string children. A container holding text and other content takes parts, not polymorphic children: `<Button onPress={save}><ButtonIcon><SaveIcon /></ButtonIcon><ButtonText>Save</ButtonText></Button>`.
**Why.** React Native renders strings only inside `<Text>`. A `typeof children === 'string'` switch hides that from callers and breaks on mixed children such as `{count} items`.
**Break:** a single-purpose component may take a `label: string` prop and render the `<Text>` itself.
