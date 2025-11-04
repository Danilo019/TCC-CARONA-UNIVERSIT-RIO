# Configuração de Índices do Firestore

Este documento explica como criar os índices necessários para o funcionamento correto do aplicativo.

## Índices Necessários

O aplicativo requer os seguintes índices compostos no Firestore:

### 1. Índice para `ride_requests` (por `rideId` e `createdAt`)
- **Collection**: `ride_requests`
- **Campos**:
  - `rideId` (Ascendente)
  - `createdAt` (Ascendente)

### 2. Índice para `rides` (por `driverId` e `dateTime`)
- **Collection**: `rides`
- **Campos**:
  - `driverId` (Ascendente)
  - `dateTime` (Descendente)

### 3. Índice para `ride_requests` (por `passengerId` e `createdAt`)
- **Collection**: `ride_requests`
- **Campos**:
  - `passengerId` (Ascendente)
  - `createdAt` (Descendente)

## Como Criar os Índices

### Opção 1: Usando Firebase CLI (Recomendado)

1. Certifique-se de ter o Firebase CLI instalado:
   ```bash
   npm install -g firebase-tools
   ```

2. Faça login no Firebase:
   ```bash
   firebase login
   ```

3. Deploy dos índices:
   ```bash
   firebase deploy --only firestore:indexes
   ```

### Opção 2: Criar Manualmente no Firebase Console

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione o projeto `carona-universitiaria`
3. Vá em **Firestore Database** → **Índices**
4. Clique em **Criar Índice**
5. Para cada índice acima, configure:
   - Collection ID
   - Campos e ordem (Ascendente/Descendente)
   - Clique em **Criar**

### Opção 3: Usando o Link do Erro

Quando o aplicativo executar e encontrar um índice faltando, ele mostrará um link no console. Basta clicar no link para criar o índice automaticamente.

## Arquivo de Configuração

O arquivo `firestore.indexes.json` contém a configuração de todos os índices necessários. Este arquivo pode ser usado com o Firebase CLI para criar os índices automaticamente.

## Verificação

Após criar os índices, eles podem levar alguns minutos para serem construídos. Você pode verificar o status no Firebase Console em **Firestore Database** → **Índices**.

Quando um índice estiver pronto, o status mudará de "Construindo" para "Habilitado".

## Nota

Os índices são necessários para consultas eficientes no Firestore. Sem eles, as consultas podem falhar ou ter performance ruim.

