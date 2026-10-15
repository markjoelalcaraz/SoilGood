# SoilGood — Test Cases (TS-01 to TS-10)

Each scenario has Happy Path + Error Path. Table format matches the class templates:

- Happy Path = blue Field | Details header
- Error Path = red Field | Details header

PDF: [SOILGOOD_TEST_CASES_TS01_TS10.pdf](SOILGOOD_TEST_CASES_TS01_TS10.pdf)

Regenerate:

```bash
python docs/testing/_gen_test_cases_pdf.py
```

| Scenario | Happy | Error |
|---|---|---|
| TS-01 Device claim | TC_DEVICE_001 | TC_DEVICE_002 |
| TS-02 Auth (register / login / logout) | TC_AUTH_001 | TC_AUTH_002 |
| TS-03 Farm onboarding | TC_ONB_001 | TC_ONB_002 |
| TS-04 ESP32 soil ingest | TC_SOIL_001 | TC_SOIL_002 |
| TS-05 Home live soil truth | TC_HOME_001 | TC_HOME_002 |
| TS-06 Water today / irrigation | TC_WATER_001 | TC_WATER_002 |
| TS-07 Out-of-band alerts | TC_ALERT_001 | TC_ALERT_002 |
| TS-08 Device offline | TC_OFFLINE_001 | TC_OFFLINE_002 |
| TS-09 Owner-only access | TC_RLS_001 | TC_RLS_002 |
| TS-10 Home AI freshness | TC_AI_001 | TC_AI_002 |

Full case text lives in `_gen_test_cases_pdf.py` so the PDF stays the submission artifact.
