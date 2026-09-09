# Olist Superset 대시보드

2026-09-09에 로컬 Superset의 **Olist Dashboard** (ID 10)를 내보낸 참고 자료다.
ChatGPT 컴퓨터 제어로 대시보드를 확인했으며, 브라우저 다운로드가 생성되지 않아
Superset의 내장 `ExportDashboardsCommand([10])`으로 같은 YAML 내보내기를 저장했다.

- [olist_dashboard.zip](olist_dashboard.zip): Superset에 가져올 수 있는 ZIP
- [olist_dashboard/](olist_dashboard/): ZIP과 동일한 YAML 파일을 펼친 디렉토리
- [기존 대시보드 이미지](../olist_dashboard.jpg): 화면 구성 참고

## 포함 내용

| 종류 | 개수 | 내용 |
|---|---:|---|
| 대시보드 | 1 | 레이아웃, 필터, 표시 설정 |
| 차트 | 9 | 매출, 결제, 배송, 카테고리, 주문 지도 |
| 데이터셋 | 3 | `mart_orders`, `mart_order_items`, 가상 데이터셋 `category_pairs` |
| DB 연결 | 1 | `olist` 연결 설정, 비밀번호 마스킹 |

원본 데이터 행은 포함하지 않는다. 실제 SQL, 차트 설정, 데이터셋 정의는 YAML에서 확인할 수 있다.
내보내기 형식 버전은 `1.0.0`이며, 대시보드의 Draft 상태도 보존했다.

## 가져오기

1. [프로젝트 실행 안내](../../README.md)에 따라 MySQL 데이터와 mart 테이블을 준비한다.
2. Superset의 **Dashboards** 목록에서 **Import dashboards**를 열고 `olist_dashboard.zip`을 선택한다.
3. `olist` 연결의 실제 비밀번호를 입력하고 가져온다. 내보낸 URI의 `XXXXXXXXXX`는 마스킹된 값이다.
4. 실행 환경에 맞게 DB 주소와 드라이버를 확인한다. 이 내보내기는
   `mysql+mysqldb` 드라이버와 `host.docker.internal:3306/olist`를 사용한다.

대시보드 YAML에서 참조하는 차트 UUID, 차트의 데이터셋 UUID, 데이터셋의 DB UUID를
모두 함께 보존했으므로 ZIP 전체를 가져온다. 같은 UUID의 기존 항목을 덮어쓰는 옵션은
필요할 때만 선택한다.
