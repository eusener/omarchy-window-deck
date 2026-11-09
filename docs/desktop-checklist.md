# Verificação no desktop Omarchy

Execute estes testes na sessão gráfica. Testes offscreen não verificam o protocolo layer-shell nem a captura de janelas reais.

- [ ] Instalar um clone novo com `omarchy plugin add` e habilitar a faixa após os desktops.
- [ ] Configurar os dois atalhos documentados; executar `hyprctl reload` e confirmar ausência de erros em `hyprctl configerrors`.
- [ ] Minimizar e restaurar em áreas flutuantes e em mosaico.
- [ ] Minimizar duas janelas do mesmo aplicativo e restaurar cada uma individualmente.
- [ ] Trocar de área e conferir o isolamento das minimizadas.
- [ ] Em dois monitores, conferir a área ativa de cada barra e a numeração local no seletor.
- [ ] Minimizar mais de seis janelas e conferir +N e o seletor filtrado.
- [ ] Navegar por teclado e mouse, confirmar, cancelar e repetir Super+Tab com o seletor aberto.
- [ ] Restaurar pelo dock e conferir a remoção do ícone da faixa.
- [ ] Abrir/fechar janelas enquanto o seletor está aberto e verificar a seleção por endereço.
- [ ] Conferir previews e fallback de janelas minimizadas/protegidas, sem restauração temporária.
- [ ] Trocar de área ou desconectar o monitor com o seletor aberto.
- [ ] Conferir escala fracionária, fonte maior e animações desativadas.
- [ ] Trocar entre temas claros e escuros sem reiniciar o plugin.
- [ ] Conferir tamanho, alinhamento e cor nativos dos ícones da barra.
- [ ] Atualizar por Git e confirmar que o novo manifesto usa o runtime correspondente.
- [ ] Retirar os atalhos pessoais e remover pelo gerenciador; conferir os atalhos padrão e as demais configurações.
