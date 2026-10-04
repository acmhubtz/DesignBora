# DesignBora Backend

Spring Boot 4.1.1 + Java 21 + PostgreSQL 18

## Kuendesha Kwa Mara ya Kwanza

1. Hakikisha PostgreSQL inaendesha: `sudo systemctl status postgresql`
2. Database: `designbora`, User: `designbora`, Password: `designbora_dev_password`
3. Endesha: `./mvnw spring-boot:run`
4. Server inapatikana: `http://localhost:8080`

## Muundo wa Package (kwa feature, si layer)

- `user/` - Auth (register/login), User entity
- `security/` - JWT, Spring Security config
- `designer/` - DesignerProfile (Individual/Company)
  - `verification/` - Hati za uthibitisho (National ID, Business License)
  - `metrics/` - Rating engine (composite_score)
- `category/` - Categories za design (Poster, Logo, n.k. + sub-categories)
- `portfolio/` - Sampuli za kazi za designer
- `offering/` - ServiceOffering (bei za huduma)
- `order/` - Order state machine + platform fee
- `payout/` - Malipo kwa designer baada ya order kukamilika
- `chat/` - WebSocket/STOMP real-time chat
- `media/` - Media storage + `draft/` (watermarking)
- `review/` - Maoni ya wateja (yanaunganishwa na rating engine)
- `search/` - Kutafuta huduma kwa category, kupangwa kwa composite_score

## Order State Machine

## Watumiaji wa Majaribio (Test Users)

| Phone | Password | Role | Maelezo |
|---|---|---|---|
| +255700000000 | admin123456 | ADMIN | |
| +255712000001 | password123 | CUSTOMER | Amina Ali |
| +255713000001 | password123 | DESIGNER | Juma Kapuya (Individual, Verified) |
| +255713000002 | password123 | DESIGNER | Bora Media Ltd (Company) |

## Endpoints Muhimu (Public - Hazihitaji Token)

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/categories`
- `GET /api/search?category={slug}`
- `GET /api/portfolio/designer/{id}`
- `GET /api/services/designer/{id}`
- `GET /api/reviews/designer/{id}`

## Endpoints Zinazohitaji Token (Authorization: Bearer {token})

- `POST /api/orders` - Unda order
- `POST /api/orders/{id}/mark-paid` - (Ya muda - itabadilishwa na payment webhook)
- `POST /api/orders/{id}/start`
- `POST /api/orders/{id}/drafts` - Upload draft (multipart)
- `POST /api/orders/{id}/submit-draft`
- `POST /api/orders/{id}/confirm-completion`
- `POST /api/reviews`
- `POST /api/verification/documents` - Upload (multipart)
- `POST /api/verification/admin/documents/{id}/approve` - ADMIN pekee

## WebSocket (Chat)

- Endpoint: `ws://localhost:8080/ws`
- Protocol: STOMP
- Subscribe: `/topic/chat/{orderId}`
- Send: `/app/chat.send/{orderId}`

## Kinachofuata (TODO)

- [ ] Payment gateway integration (Selcom/AzamPay webhook)
- [ ] Video watermarking (FFmpeg)
- [ ] Admin endpoints za payouts
- [ ] Flutter mobile app
