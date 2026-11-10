# Changelog

## 1.4.0

- Remove o backend Python. Super+M e Super+Ctrl+M rodam como funções Lua dentro do Hyprland, sem iniciar processos; antes cada atalho levava cerca de 130 ms só para iniciar o Python.
- O seletor e a barra leem as janelas com `hyprctl -j clients` e restauram com `hyprctl eval`, sem Python. A normalização das janelas fica em `Model.js` e todas as validações de estado e origem continuam na mesma chamada Lua que move a janela.
- Os atalhos recarregam `operations.lua` a cada uso, então atualizações do plugin valem sem `hyprctl reload`. Sem o plugin instalado, os atalhos padrão voltam.
- O fundo das miniaturas de janelas transparentes segue a opção de blur do Hyprland, ligada pelo modo Glassy. Atrás da janela aparece o trecho do papel de parede que fica atrás dela no desktop: desfocado e com o brilho e contraste do blur quando ele está ligado, nítido quando está desligado. Sem papel de parede estático (vídeo ou arquivo ausente), continua a cor de fundo do tema.
- Corrige a escolha de uma janela no seletor quando outra janela da área está maximizada ou em tela cheia: a escolhida ficava escondida atrás dela. Ao fechar, o seletor devolvia o foco à janela anterior, que retomava a maximização. Agora a restauração acontece depois que o seletor fecha, e a janela escolhida assume a maximização, seguindo `misc:on_focus_under_fullscreen = 1` do Omarchy; com outros valores, a maximizada só é desfeita.
- O seletor ganha vidro como os overlays do Omarchy: com o blur do Hyprland ligado (modo Glassy), o que fica atrás dele é desfocado. A sombra do painel e dos cartões fica suave e só aparece em superfícies opacas; antes era um retângulo sólido que vazava através do vidro.
- **Migração:** substitua as linhas de Super+M e Super+Ctrl+M em `bindings.lua` pelo bloco novo do README, que também traz a regra de blur do seletor. As linhas antigas apontam para `backend.py`, que não existe mais.

## 1.3.2

- Evita reiniciar todas as capturas do Super+Tab quando títulos e outros metadados das janelas são atualizados, reduzindo o flicker durante atualizações frequentes.
- Testes de UI verificam a continuidade das miniaturas e a criação de capturas novas quando a lista de janelas muda.

## 1.3.1

- Super+Ctrl+M restaura primeiro o tamanho anterior da janela ativa maximizada. Quando ela não está maximizada, continua trazendo a minimizada mais recente da área atual.

## 1.3.0

- Super+Ctrl+M restaura a minimizada mais recente no histórico de foco da área ativa, com validação da área e da origem dentro do compositor.
- Super+Ctrl+Shift+M maximiza a janela ativa usando o modo nativo do Omarchy.
- Instalador local atualiza os atalhos gerenciados; Super+M continua minimizando.

## 1.2.1

- Corrige a sobreposição do desktop nas miniaturas de janelas transparentes, como terminais com Glassy, forçando a composição alfa sobre o fundo do cartão.
- Teste de renderização reproduz o defeito de textura exportada com metadados opacos e pixels transparentes, em temas claros e escuros.

## 1.2.0

- Distribuição pronta para `omarchy plugin add`, com manifesto na raiz e runtime gerado incluído no Git.
- Atualização e remoção pelo gerenciador do Omarchy, sem hooks de instalação.
- Componentes QML em caminhos identificados por conteúdo para evitar cache de versões anteriores.
- Instalador local impede substituição de checkouts Git.
- Ícones monocromáticos nativos e cores e fontes do tema ativo.
- Minimização por área, restauração validada dentro do compositor e seletor de janelas com captura em memória.
- Documentação portátil de atalhos, migração, dependências e limites de captura.
- Validação de publicação e CI para os testes Python e JavaScript.
