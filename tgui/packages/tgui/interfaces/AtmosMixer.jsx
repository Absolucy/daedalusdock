import { useBackend } from '../backend';
import {
  Button,
  LabeledList,
  NumberInput,
  ProgressBar,
  Section,
} from '../components';
import { formatSiUnit } from '../format';
import { Window } from '../layouts';

export const AtmosMixer = (props) => {
  const { act, data } = useBackend();
  return (
    <Window width={370} height={179}>
      <Window.Content>
        <Section>
          <LabeledList>
            <LabeledList.Item label="Power">
              <Button
                icon={data.on ? 'power-off' : 'times'}
                content={data.on ? 'On' : 'Off'}
                selected={data.on}
                onClick={() => act('power')}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Output Pressure">
              <NumberInput
                animated
                value={parseFloat(data.set_pressure)}
                unit="kPa"
                width="75px"
                minValue={0}
                maxValue={data.max_pressure}
                step={10}
                onChange={(value) =>
                  act('pressure', {
                    pressure: value,
                  })
                }
              />
              <Button
                ml={1}
                icon="plus"
                content="Max"
                disabled={data.set_pressure === data.max_pressure}
                onClick={() =>
                  act('pressure', {
                    pressure: 'max',
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Main Node" labelColor="green">
              <NumberInput
                animated
                value={data.node1_concentration}
                unit="%"
                width="60px"
                minValue={0}
                maxValue={100}
                stepPixelSize={2}
                onDrag={(value) =>
                  act('node1', {
                    concentration: value,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Side Node" labelColor="blue">
              <NumberInput
                animated
                value={data.node2_concentration}
                unit="%"
                width="60px"
                minValue={0}
                maxValue={100}
                stepPixelSize={2}
                onDrag={(value) =>
                  act('node2', {
                    concentration: value,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Power Usage">
              <ProgressBar
                value={data.last_draw}
                maxValue={data.max_power}
                color="yellow"
              >
                {formatSiUnit(data.last_draw, 0, 'W')}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
