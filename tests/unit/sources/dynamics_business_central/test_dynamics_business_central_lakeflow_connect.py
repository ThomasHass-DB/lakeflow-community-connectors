from pathlib import Path

from databricks.labs.community_connector.sources.dynamics_business_central.dynamics_business_central import (
    DynamicsBusinessCentralLakeflowConnect,
)
from tests.unit.sources import test_suite
from tests.unit.sources.test_suite import LakeflowConnectTester
from tests.unit.sources.test_utils import load_config


def test_dynamics_business_central_connector():
    config_dir = Path(__file__).parent / "configs"
    config = load_config(config_dir / "dev_config.json")
    table_config = load_config(config_dir / "dev_table_config.json")

    test_suite.LakeflowConnect = DynamicsBusinessCentralLakeflowConnect

    tester = LakeflowConnectTester(config, table_config, sample_records=5)
    report = tester.run_all_tests()
    tester.print_report(report, show_details=True)

    assert report.passed_tests == report.total_tests, (
        f"Test suite had failures: {report.failed_tests} failed, {report.error_tests} errors"
    )
