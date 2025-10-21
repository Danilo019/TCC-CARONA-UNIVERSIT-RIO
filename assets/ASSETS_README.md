# Assets do Onboarding - Carona Uni

## 📁 Estrutura de Assets

Esta pasta deve conter as imagens utilizadas nas telas de onboarding.

### Imagens Necessárias

Coloque as seguintes imagens na pasta `assets/images/`:

1. **onboarding_security.png**
   - **Tema:** Segurança
   - **Título da tela:** "Bem-vindo à Carona Uni!"
   - **Sugestão de conteúdo:** Ilustração representando segurança, confiança, verificação de usuários

2. **onboarding_ease.png**
   - **Tema:** Facilidade
   - **Título da tela:** "Ofereça ou Encontre Caronas"
   - **Sugestão de conteúdo:** Ilustração representando facilidade de uso, mapa, rotas, conexão entre pessoas

3. **onboarding_economy.png**
   - **Tema:** Economia
   - **Título da tela:** "Economize e Faça a Diferença"
   - **Sugestão de conteúdo:** Ilustração representando economia, sustentabilidade, compartilhamento

---

## 🎨 Especificações Técnicas

### Dimensões Recomendadas

- **Largura:** 800-1200px
- **Altura:** 600-900px
- **Proporção:** 4:3 ou 16:9
- **Formato:** PNG com fundo transparente (recomendado) ou JPG

### Resolução para Diferentes Densidades

Para melhor qualidade em diferentes dispositivos, você pode fornecer múltiplas resoluções:

```
assets/
└── images/
    ├── onboarding_security.png      (1x - 800x600)
    ├── 2.0x/
    │   └── onboarding_security.png  (2x - 1600x1200)
    ├── 3.0x/
    │   └── onboarding_security.png  (3x - 2400x1800)
    └── ... (mesmo para as outras imagens)
```

### Paleta de Cores Sugerida

Para harmonizar com o gradiente azul oceano do onboarding:

- **Azul escuro:** #0D47A1
- **Azul médio:** #1976D2
- **Azul claro:** #42A5F5
- **Azul céu:** #64B5F6
- **Laranja destaque:** #FF6F00
- **Branco:** #FFFFFF

---

## 🖼️ Fontes de Ilustrações

### Opções Gratuitas

1. **Undraw** - https://undraw.co/illustrations
   - Ilustrações vetoriais personalizáveis
   - Permite alterar a cor principal

2. **Storyset** - https://storyset.com/
   - Ilustrações animadas e estáticas
   - Várias categorias disponíveis

3. **Freepik** - https://www.freepik.com/
   - Vasta biblioteca de ilustrações
   - Requer atribuição na versão gratuita

4. **Flaticon** - https://www.flaticon.com/
   - Ícones e ilustrações simples
   - Boa para estilos minimalistas

### Opções Pagas

1. **Lottie Files** - https://lottiefiles.com/
   - Animações em formato JSON
   - Requer integração com `lottie_flutter`

2. **Envato Elements** - https://elements.envato.com/
   - Biblioteca premium
   - Licença comercial incluída

---

## 🎯 Sugestões de Palavras-chave para Busca

### Para onboarding_security.png
- "security illustration"
- "trust verification"
- "user authentication"
- "safe connection"
- "verified user"

### Para onboarding_ease.png
- "map route illustration"
- "easy navigation"
- "location sharing"
- "ride sharing app"
- "connection people"

### Para onboarding_economy.png
- "save money illustration"
- "eco friendly"
- "sustainability"
- "car sharing"
- "green planet"

---

## 🛠️ Ferramentas de Edição

### Remover Fundo

- **Remove.bg** - https://www.remove.bg/
- **Adobe Express** - https://www.adobe.com/express/

### Redimensionar Imagens

- **TinyPNG** - https://tinypng.com/ (compressão)
- **ImageOptim** - https://imageoptim.com/ (otimização)
- **Squoosh** - https://squoosh.app/ (redimensionamento)

### Edição Vetorial

- **Figma** - https://www.figma.com/
- **Inkscape** - https://inkscape.org/ (gratuito)
- **Adobe Illustrator** - https://www.adobe.com/products/illustrator.html

---

## 📝 Checklist de Assets

- [ ] onboarding_security.png adicionado
- [ ] onboarding_ease.png adicionado
- [ ] onboarding_economy.png adicionado
- [ ] Imagens têm fundo transparente (se aplicável)
- [ ] Imagens estão otimizadas (tamanho de arquivo reduzido)
- [ ] Cores harmonizam com o gradiente azul oceano
- [ ] Imagens testadas em diferentes tamanhos de tela
- [ ] Assets declarados no pubspec.yaml

---

## 🚨 Fallback

Se você ainda não tem as imagens, **não se preocupe!**

O código já possui um **fallback automático** que exibe um ícone de carro caso a imagem não seja encontrada:

```dart
errorBuilder: (context, error, stackTrace) {
  return Icon(
    Icons.directions_car,
    size: 120,
    color: AppColors.oceanMediumBlue,
  );
},
```

Isso permite que você teste o onboarding mesmo sem as imagens finais.

---

## 📞 Suporte

Se você precisar de ajuda para criar ou encontrar as ilustrações:

1. Use as fontes gratuitas listadas acima
2. Customize as cores para combinar com o tema azul oceano
3. Otimize as imagens antes de adicionar ao projeto
4. Teste em diferentes dispositivos

---

**Dica:** Comece com ilustrações simples e melhore gradualmente. O importante é manter a consistência visual com o gradiente azul oceano!

