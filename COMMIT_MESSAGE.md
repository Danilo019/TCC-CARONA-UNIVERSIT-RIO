# Mensagem de Commit

```
feat: Implementa mensagens em tempo real e corrige fluxo de solicitação de caronas

- Implementa sistema de mensagens em tempo real usando Firebase Realtime Database
- Adiciona contador de mensagens não lidas por conversa e total na navegação
- Corrige fluxo de solicitação de carona na tela de passageiro para criar solicitação
  pendente ao invés de reservar diretamente, alinhando com o comportamento do mapa
- Adiciona tratamento de erros robusto com timeouts e fallbacks para evitar travamentos
- Implementa marcação automática de mensagens como lidas ao abrir o chat
- Adiciona exibição da última mensagem e timestamp na lista de conversas
- Cria arquivo firestore.indexes.json com índices necessários para consultas
- Adiciona documentação sobre fluxo de comunicação e configuração de índices

BREAKING CHANGE: Solicitações de carona agora criam RideRequest com status 'pending'
ao invés de reservar vaga diretamente, permitindo que motorista aceite/rejeite
```

